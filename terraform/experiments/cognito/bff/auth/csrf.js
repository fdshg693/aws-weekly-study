// CSRF保護（Double Submit Cookie パターン）
// ==========================================
// Cookie認証ではCSRF（Cross-Site Request Forgery）攻撃のリスクがあります。
//
// CSRF攻撃の仕組み:
// 1. ユーザーがBFFにログイン済み（bff_session Cookieがある）
// 2. 攻撃者のサイトに <form action="http://localhost:3000/auth/logout" method="POST"> がある
// 3. ユーザーが攻撃者のサイトを訪問
// 4. フォームが自動送信 → ブラウザがbff_session Cookieを自動付与
// 5. BFFはCookieが正当なので、リクエストを処理してしまう
//
// Double Submit Cookie パターンによる防御:
// ┌───────────────────────────────────────────────────────────────────────┐
// │ 1. BFFがCSRFトークンを「通常のCookie」（HttpOnly=false）に設定       │
// │ 2. フロントエンドのJSがCookieからトークンを読み取る                  │
// │ 3. フロントエンドがリクエストヘッダー（x-csrf-token）にトークンを付与│
// │ 4. BFFがCookieの値とヘッダーの値を比較 → 一致すれば正当なリクエスト  │
// └───────────────────────────────────────────────────────────────────────┘
//
// なぜこれで防げるのか:
// - 攻撃者のサイトからはCookie値を読み取れない（Same-Origin Policy）
// - ヘッダーに正しいトークンを付与できない
// - Cookieは自動送信されるが、ヘッダーは手動で付与する必要がある
//
// SameSite=Lax との多層防御:
// - SameSite=Lax: GETリクエストにはCookieが送信される
// - CSRFトークン: POST/PUT/DELETE のみ検証
// → 両方を併用することで、より堅牢な防御を実現

import crypto from 'crypto'

export const CSRF_COOKIE_NAME = 'csrf_token'
export const CSRF_HEADER_NAME = 'x-csrf-token'

/**
 * CSRFトークンを発行するミドルウェア
 * まだCSRF Cookieがない場合に新しいトークンを生成します。
 */
export function csrfTokenMiddleware(req, res, next) {
  if (!req.cookies[CSRF_COOKIE_NAME]) {
    const token = crypto.randomBytes(32).toString('hex')
    // Lambda環境（API Gateway）ではフロントエンド（Amplify）と異なるドメインになるため、
    // SameSite=None + Secure=true が必要です。
    const isLambda = !!process.env.AWS_LAMBDA_FUNCTION_NAME
    res.cookie(CSRF_COOKIE_NAME, token, {
      httpOnly: false,        // フロントエンドのJSで読めるようにする（これがDouble Submitの要）
      secure: isLambda || process.env.NODE_ENV === 'production',
      sameSite: isLambda ? 'none' : 'lax',
      path: '/',
      maxAge: 24 * 60 * 60 * 1000,
    })
  }
  next()
}

/**
 * CSRFトークンを検証するミドルウェア
 * 状態変更リクエスト（POST/PUT/DELETE）でCookieとヘッダーの値を比較します。
 * GET/HEAD/OPTIONS は冪等なため検証をスキップします。
 */
export function csrfProtectionMiddleware(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next()
  }

  const cookieToken = req.cookies[CSRF_COOKIE_NAME]
  const headerToken = req.headers[CSRF_HEADER_NAME]

  if (!cookieToken || !headerToken || cookieToken !== headerToken) {
    return res.status(403).json({
      error: 'CSRF token mismatch',
      message: 'CSRFトークンが一致しません。ページを再読み込みしてください。',
    })
  }

  next()
}
