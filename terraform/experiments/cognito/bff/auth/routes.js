// 認証ルート
// ==========
// BFFの認証エンドポイントを定義します。
//
// エンドポイント一覧:
// ┌────────┬──────────────────┬──────────────────────────────────────────┐
// │ Method │ Path             │ 処理                                     │
// ├────────┼──────────────────┼──────────────────────────────────────────┤
// │ GET    │ /auth/login      │ PKCE+state+nonce生成 → Hosted UIへ       │
// │ GET    │ /auth/callback   │ state検証→トークン交換→署名検証→セッション│
// │ POST   │ /auth/logout     │ セッション破棄 → CognitoログアウトURL返却│
// │ GET    │ /auth/me         │ 現在のユーザー情報取得                   │
// │ POST   │ /auth/refresh    │ トークンリフレッシュ                     │
// └────────┴──────────────────┴──────────────────────────────────────────┘
//
// 認証フロー全体像:
//
// ブラウザ           BFF (このファイル)        Cognito Hosted UI
// ─────────────────────────────────────────────────────────────────
//   │                    │                         │
//   │ GET /auth/login    │                         │
//   │───────────────────>│                         │
//   │                    │ generate:                │
//   │                    │  code_verifier           │
//   │                    │  code_challenge          │
//   │                    │  state                   │
//   │                    │  nonce                   │
//   │  302 Redirect      │                         │
//   │<───────────────────│                         │
//   │                                              │
//   │ GET /oauth2/authorize?code_challenge&state&nonce
//   │─────────────────────────────────────────────>│
//   │                                              │
//   │          ユーザーがログイン                   │
//   │                                              │
//   │ 302 /auth/callback?code=xxx&state=yyy        │
//   │<─────────────────────────────────────────────│
//   │                    │                         │
//   │ GET /auth/callback │                         │
//   │───────────────────>│                         │
//   │                    │ verify state             │
//   │                    │ POST /oauth2/token       │
//   │                    │  + code                  │
//   │                    │  + code_verifier         │
//   │                    │  + client_secret         │
//   │                    │────────────────────────>│
//   │                    │ { access_token,          │
//   │                    │   id_token,              │
//   │                    │   refresh_token }        │
//   │                    │<────────────────────────│
//   │                    │                         │
//   │                    │ verify JWT signature     │
//   │                    │ verify nonce             │
//   │                    │ create session           │
//   │                    │                         │
//   │ 302 → frontend     │                         │
//   │ Set-Cookie: bff_session (HttpOnly)           │
//   │<───────────────────│                         │
//   │                    │                         │
//   │ GET /auth/me       │                         │
//   │ Cookie: bff_session│                         │
//   │───────────────────>│                         │
//   │ { user, claims }   │                         │
//   │<───────────────────│                         │

import { Router } from 'express'
import {
  generateCodeVerifier,
  generateCodeChallenge,
  generateState,
  generateNonce,
  getAuthorizeUrl,
  exchangeCodeForTokens,
  refreshTokens,
  getLogoutUrl,
} from './cognito.js'
import {
  createSession,
  getSession,
  updateSession,
  deleteSession,
  savePendingAuthorization,
  consumePendingAuthorization,
  getSessionCookieOptions,
  SESSION_COOKIE_NAME,
} from './session.js'
import { verifyIdToken, verifyAccessToken } from './jwt.js'
import { csrfTokenMiddleware, csrfProtectionMiddleware } from './csrf.js'

export function authRouter(config) {
  const router = Router()

  // CSRF保護ミドルウェア
  router.use(csrfTokenMiddleware)
  router.use(csrfProtectionMiddleware)

  // ========================================
  // GET /auth/login
  // ========================================
  // ログインフローを開始します。
  //
  // 処理:
  // 1. PKCE (code_verifier, code_challenge) を生成
  // 2. state（CSRF保護）を生成
  // 3. nonce（リプレイ攻撃防止）を生成
  // 4. 一時データをストアに保存（コールバックで使用）
  // 5. Hosted UIの認可URLにリダイレクト
  //
  // SPA版との違い:
  // - SPA版: code_verifierをsessionStorageに保存（ブラウザ側）
  // - BFF版: code_verifierをストアに保存（ブラウザに露出しない）

  router.get('/login', async (req, res) => {
    const codeVerifier = generateCodeVerifier()
    const codeChallenge = generateCodeChallenge(codeVerifier)
    const state = generateState()
    const nonce = generateNonce()

    // ストアに一時保存（stateをキーにして保存）
    await savePendingAuthorization(state, { codeVerifier, nonce })

    const authorizeUrl = getAuthorizeUrl(config, { codeChallenge, state, nonce })

    console.log(`[LOGIN] Redirecting to Hosted UI (state: ${state.substring(0, 8)}...)`)
    res.redirect(authorizeUrl)
  })

  // ========================================
  // GET /auth/callback
  // ========================================
  // Cognito Hosted UIからのコールバックを処理します。
  //
  // 処理:
  // 1. エラーチェック（ユーザーがキャンセルした場合等）
  // 2. stateパラメータを検証（CSRF保護）
  // 3. 認可コード + code_verifier + client_secret でトークン交換
  // 4. IDトークンの署名をJWKSで検証
  // 5. IDトークンのnonceを検証（リプレイ攻撃防止）
  // 6. アクセストークンの署名を検証
  // 7. セッション作成 → HttpOnly Cookieに設定
  // 8. フロントエンドにリダイレクト
  //
  // セキュリティ対策の解決:
  // - #1 トークン平文保存 → ストアに保存、ブラウザにはセッションIDのみ
  // - #2 トークン検証なし → JWKS署名検証を実施
  // - #3 JWT署名検証なし → JWKS署名検証を実施
  // - #5 期限切れチェック → joseライブラリがexp自動検証
  // - #8 state欠如 → state生成・検証を実施

  router.get('/callback', async (req, res) => {
    try {
      const { code, state, error: callbackError, error_description } = req.query

      // Cognitoからのエラー（ユーザーキャンセル等）
      if (callbackError) {
        console.error(`[CALLBACK] Cognito error: ${callbackError} - ${error_description}`)
        return res.redirect(
          `${config.frontendOrigin}/?error=${encodeURIComponent(error_description || callbackError)}`
        )
      }

      if (!code || !state) {
        return res.status(400).json({ error: 'Missing code or state parameter' })
      }

      // state検証: ストアから取得（取得と同時に削除 = ワンタイム使用）
      const pending = await consumePendingAuthorization(state)
      if (!pending) {
        console.error(`[CALLBACK] Invalid state: ${state.substring(0, 8)}...`)
        return res.status(400).json({
          error: 'Invalid state',
          message: 'stateパラメータが一致しません。CSRF攻撃の可能性があります。',
        })
      }

      console.log(`[CALLBACK] State verified, exchanging code for tokens...`)

      // トークン交換（client_secret + code_verifier）
      const tokenResponse = await exchangeCodeForTokens(
        config, code, pending.codeVerifier
      )

      console.log(`[CALLBACK] Tokens received, verifying signatures...`)

      // IDトークンの署名 + nonce検証
      const idTokenClaims = await verifyIdToken(
        config, tokenResponse.id_token, pending.nonce
      )

      // アクセストークンの署名検証
      const accessTokenClaims = await verifyAccessToken(
        config, tokenResponse.access_token
      )

      console.log(`[CALLBACK] JWT verified for user: ${idTokenClaims.email}`)

      // セッション作成（トークンはストアにのみ保存）
      const sessionId = await createSession({
        tokens: {
          accessToken: tokenResponse.access_token,
          idToken: tokenResponse.id_token,
          refreshToken: tokenResponse.refresh_token,
        },
        idTokenClaims,
        accessTokenClaims,
      })

      // HttpOnly Cookie にセッションIDを設定
      res.cookie(SESSION_COOKIE_NAME, sessionId, getSessionCookieOptions())

      console.log(`[CALLBACK] Session created, redirecting to frontend`)

      // フロントエンドにリダイレクト
      res.redirect(config.frontendOrigin + '/')
    } catch (err) {
      console.error('[CALLBACK] Error:', err.message)
      res.redirect(
        `${config.frontendOrigin}/?error=${encodeURIComponent(err.message)}`
      )
    }
  })

  // ========================================
  // POST /auth/logout
  // ========================================
  // ログアウト処理:
  // 1. サーバーサイドセッションを削除
  // 2. セッションCookieをクリア
  // 3. CognitoのログアウトURLを返却（フロントエンドがリダイレクト）
  //
  // なぜPOSTか:
  // ログアウトは状態変更操作のため、GETではなくPOSTを使用。
  // CSRF保護が適用され、攻撃者がログアウトさせることを防ぎます。

  router.post('/logout', async (req, res) => {
    const sessionId = req.cookies[SESSION_COOKIE_NAME]
    if (sessionId) {
      await deleteSession(sessionId)
      console.log(`[LOGOUT] Session deleted`)
    }

    // Cookieクリア
    res.clearCookie(SESSION_COOKIE_NAME, { path: '/' })

    // CognitoログアウトURLを返却
    // ブラウザをこのURLにリダイレクトすると、Cognito Hosted UIのセッションも無効化
    const logoutUrl = getLogoutUrl(config)
    res.json({ logoutUrl })
  })

  // ========================================
  // GET /auth/me
  // ========================================
  // 現在のログインユーザー情報を返します。
  //
  // フロントエンドはページ読み込み時にこのエンドポイントを呼び出し、
  // 認証状態を確認します。
  //
  // SPA版との違い:
  // - SPA版: sessionStorageからトークンを読み取り、Base64デコード
  // - BFF版: HttpOnly CookieからセッションIDを取得、サーバーでクレームを返却
  //         → トークン本体はブラウザに存在しない

  router.get('/me', async (req, res) => {
    const sessionId = req.cookies[SESSION_COOKIE_NAME]
    const session = await getSession(sessionId)

    if (!session) {
      return res.status(401).json({
        authenticated: false,
        message: '未ログインです',
      })
    }

    // アクセストークンの有効期限チェック
    const now = Math.floor(Date.now() / 1000)
    const isAccessTokenExpired = session.accessTokenClaims.exp < now

    res.json({
      authenticated: true,
      user: {
        email: session.idTokenClaims.email,
        name: session.idTokenClaims.name || null,
        sub: session.idTokenClaims.sub,
        emailVerified: session.idTokenClaims.email_verified,
      },
      claims: {
        idToken: session.idTokenClaims,
        accessToken: session.accessTokenClaims,
      },
      tokenStatus: {
        accessTokenExpired: isAccessTokenExpired,
        accessTokenExpiresAt: new Date(session.accessTokenClaims.exp * 1000).toISOString(),
      },
    })
  })

  // ========================================
  // POST /auth/refresh
  // ========================================
  // トークンをリフレッシュします。
  //
  // アクセストークンの有効期限（1時間）が切れた場合に、
  // リフレッシュトークン（有効期限30日）を使って新しいトークンを取得します。
  // ユーザーの再ログインは不要です。

  router.post('/refresh', async (req, res) => {
    try {
      const sessionId = req.cookies[SESSION_COOKIE_NAME]
      const session = await getSession(sessionId)

      if (!session || !session.tokens.refreshToken) {
        return res.status(401).json({
          error: 'No session or refresh token',
          message: 'セッションまたはリフレッシュトークンがありません',
        })
      }

      console.log(`[REFRESH] Refreshing tokens...`)

      // トークンリフレッシュ
      const tokenResponse = await refreshTokens(config, session.tokens.refreshToken)

      // 新しいトークンを検証
      const idTokenClaims = await verifyIdToken(config, tokenResponse.id_token)
      const accessTokenClaims = await verifyAccessToken(config, tokenResponse.access_token)

      // セッション更新
      // NOTE: Cognitoのrefreshレスポンスにrefresh_tokenは含まれないため、既存のものを維持
      await updateSession(sessionId, {
        tokens: {
          accessToken: tokenResponse.access_token,
          idToken: tokenResponse.id_token,
          refreshToken: session.tokens.refreshToken,
        },
        idTokenClaims,
        accessTokenClaims,
      })

      console.log(`[REFRESH] Tokens refreshed for user: ${idTokenClaims.email}`)

      res.json({
        success: true,
        message: 'トークンをリフレッシュしました',
        tokenStatus: {
          accessTokenExpiresAt: new Date(accessTokenClaims.exp * 1000).toISOString(),
        },
      })
    } catch (err) {
      console.error('[REFRESH] Error:', err.message)
      res.status(401).json({
        error: 'Refresh failed',
        message: err.message,
      })
    }
  })

  return router
}
