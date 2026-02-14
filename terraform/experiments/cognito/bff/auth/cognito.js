// Cognito OAuth Helper（サーバーサイド版）
// ========================================
// BFFからCognito Hosted UIのOAuthエンドポイントと通信します。
//
// フロントエンド版（frontend/src/auth/cognito.js）との違い:
// ┌────────────────────┬────────────────────────┬──────────────────────────┐
// │                    │ SPA版（フロントエンド） │ BFF版（このファイル）     │
// ├────────────────────┼────────────────────────┼──────────────────────────┤
// │ client_secret      │ なし（Public Client）   │ あり（Confidential）     │
// │ PKCE               │ ブラウザで生成          │ サーバーで生成           │
// │ state              │ なし（脆弱性#8）        │ あり（CSRF保護）         │
// │ nonce              │ なし                    │ あり（リプレイ攻撃防止） │
// │ トークン交換       │ ブラウザから直接        │ サーバーから（秘密保持） │
// │ Crypto API         │ Web Crypto API          │ Node.js crypto           │
// └────────────────────┴────────────────────────┴──────────────────────────┘

import crypto from 'crypto'

// ========================================
// PKCE（Proof Key for Code Exchange）
// ========================================
// RFC 7636: https://tools.ietf.org/html/rfc7636
//
// PKCEフロー:
// 1. code_verifier（ランダム文字列）を生成
// 2. code_challenge = BASE64URL(SHA256(code_verifier)) を計算
// 3. 認可リクエストにcode_challengeを含める
// 4. トークン交換時にcode_verifierを送信
// → Cognito がSHA256(code_verifier) == code_challenge を検証
// → 認可コードを傍受しても、code_verifierがなければトークン取得不可

/**
 * code_verifierを生成（サーバーサイド版）
 * @returns {string} Base64URL形式のcode_verifier（43文字）
 */
export function generateCodeVerifier() {
  return crypto.randomBytes(32).toString('base64url')
}

/**
 * code_verifierからcode_challengeを生成
 * SHA-256ハッシュ → Base64URL変換
 */
export function generateCodeChallenge(codeVerifier) {
  return crypto.createHash('sha256').update(codeVerifier).digest('base64url')
}

// ========================================
// state パラメータ
// ========================================
// OAuth 2.0 CSRF保護メカニズム（RFC 6749 Section 10.12）
//
// 攻撃シナリオ（stateなし）:
// 1. 攻撃者が自分のアカウントで認可コードを取得
// 2. 被害者に攻撃者の認可コード付きコールバックURLを踏ませる
// 3. 被害者が攻撃者のアカウントにログインしてしまう（ログインCSRF）
//
// state による防御:
// 1. BFFが認可リクエスト前にランダムなstateを生成・保存
// 2. コールバック時にCognitoが同じstateを返す
// 3. BFFが保存したstateと比較 → 一致しなければ拒否

/**
 * stateパラメータを生成
 * @returns {string} 32文字のhex文字列
 */
export function generateState() {
  return crypto.randomBytes(16).toString('hex')
}

// ========================================
// nonce パラメータ
// ========================================
// OIDC IDトークンのリプレイ攻撃防止
//
// 攻撃シナリオ（nonceなし）:
// 1. 攻撃者が正規のIDトークンを入手（ログ漏洩、別セッションからの窃取等）
// 2. そのIDトークンを別のセッションに注入
// 3. 被害者が攻撃者の身元情報でログイン状態になる
//
// nonce による防御:
// 1. BFFが認可リクエスト前にランダムなnonceを生成・保存
// 2. CognitoがIDトークンのclaimsに同じnonceを埋め込む
// 3. BFFがIDトークン検証時にnonceの一致を確認 → 不一致なら拒否

/**
 * nonceパラメータを生成
 * @returns {string} 32文字のhex文字列
 */
export function generateNonce() {
  return crypto.randomBytes(16).toString('hex')
}

// ========================================
// OAuth エンドポイント
// ========================================

/**
 * Hosted UIの認可URLを生成
 * PKCE + state + nonce を含む完全なURLを構築します。
 *
 * @param {object} config - BFF設定
 * @param {object} params - { codeChallenge, state, nonce }
 * @returns {string} 認可URL
 */
export function getAuthorizeUrl(config, { codeChallenge, state, nonce }) {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    scope: 'openid email profile',
    code_challenge_method: 'S256',
    code_challenge: codeChallenge,
    state,
    nonce,
  })
  return `https://${config.cognitoDomain}/oauth2/authorize?${params}`
}

/**
 * 認可コードをトークンに交換
 *
 * Confidential Client + PKCE の二重保護:
 * - client_secret: このBFFが正規のクライアントであることを証明
 * - code_verifier: この認可リクエストの送信者であることを証明
 * → 片方だけでは不十分。両方揃って初めてトークンが発行される。
 *
 * @param {object} config - BFF設定
 * @param {string} code - 認可コード
 * @param {string} codeVerifier - PKCE code_verifier
 * @returns {Promise<object>} { access_token, id_token, refresh_token, expires_in, token_type }
 */
export async function exchangeCodeForTokens(config, code, codeVerifier) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: config.clientId,
    client_secret: config.clientSecret,
    code,
    redirect_uri: config.redirectUri,
    code_verifier: codeVerifier,
  })

  const response = await fetch(`https://${config.cognitoDomain}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  })

  if (!response.ok) {
    const errorBody = await response.text()
    throw new Error(`Token exchange failed (${response.status}): ${errorBody}`)
  }

  return response.json()
}

/**
 * リフレッシュトークンで新しいアクセストークンを取得
 *
 * リフレッシュトークンフロー:
 * - アクセストークン有効期限（1時間）後に使用
 * - ユーザーの再ログインなしで新しいトークンを取得
 * - リフレッシュトークン自体の有効期限: 30日（dev.tfvars設定）
 * - レスポンスにrefresh_tokenは含まれない（既存のものを再利用）
 */
export async function refreshTokens(config, refreshToken) {
  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: config.clientId,
    client_secret: config.clientSecret,
    refresh_token: refreshToken,
  })

  const response = await fetch(`https://${config.cognitoDomain}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  })

  if (!response.ok) {
    const errorBody = await response.text()
    throw new Error(`Token refresh failed (${response.status}): ${errorBody}`)
  }

  return response.json()
}

/**
 * Hosted UIのログアウトURLを生成
 * ブラウザをこのURLにリダイレクトすると、CognitoのセッションCookieも無効化されます。
 */
export function getLogoutUrl(config) {
  const params = new URLSearchParams({
    client_id: config.clientId,
    logout_uri: config.frontendOrigin + '/',
  })
  return `https://${config.cognitoDomain}/logout?${params}`
}
