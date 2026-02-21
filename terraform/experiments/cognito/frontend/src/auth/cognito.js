// Cognito BFF API クライアント
// ============================
// BFFパターンでは、フロントエンドはCognitoと直接通信しません。
// 代わりに、BFFサーバーの認証APIを呼び出します。
//
// 変更前（SPA直接）:
//   ブラウザ → Cognito /oauth2/token（トークンがブラウザに露出）
//
// 変更後（BFF経由）:
//   ブラウザ → BFF /auth/*（トークンはサーバーサイドのみ）
//   → ブラウザにはHttpOnly CookieのセッションIDのみ存在
//
// BFF APIのベースURL:
// - ローカル開発: '' （Viteプロキシが /auth/* を localhost:3000 に転送）
// - Amplifyデプロイ: API Gateway URL （config.json の bffUrl から取得）
//
// 各関数は credentials: 'include' を指定してCookieを送受信します。

// BFF APIのベースURL（initBffConfig で設定される）
let bffBaseUrl = ''

/**
 * config.json からBFF設定を読み込み
 * Amplifyデプロイ時: config.json の bffUrl を使用
 * ローカル開発時: config.json が無い or bffUrl が無い → 空文字（Viteプロキシ）
 */
export async function initBffConfig() {
  const config = await loadConfig()
  if (config?.bffUrl) {
    bffBaseUrl = config.bffUrl.replace(/\/$/, '')
    console.log('[auth] クラウド環境: BFF URL =', bffBaseUrl)
  } else {
    console.log('[auth] ローカル環境: Viteプロキシ使用')
  }
}

/**
 * config.json を読み込む
 * @returns {Promise<object|null>} 設定オブジェクト、取得できない場合は null
 */
async function loadConfig() {
  try {
    const res = await fetch('/config.json')
    return res.ok ? await res.json() : null
  } catch {
    return null
  }
}

/**
 * BFF APIのベースURLを取得（同期版）
 * LoginButton等のコンポーネントから使用
 */
export function getBffUrl() {
  return bffBaseUrl
}

/**
 * BFF /auth/me を呼び出し、認証状態を取得
 * HttpOnly CookieのセッションIDが自動送信されます。
 *
 * @returns {Promise<object>} { authenticated, user?, claims?, tokenStatus? }
 */
export async function fetchAuthMe() {
  const res = await fetch(`${bffBaseUrl}/auth/me`, { credentials: 'include' })
  return res.json()
}

/**
 * BFF /auth/logout を呼び出し、セッションを破棄
 * CSRFトークンをヘッダーに付与する必要があります。
 *
 * @returns {Promise<object>} { logoutUrl }
 */
export async function postAuthLogout() {
  const csrfToken = getCsrfToken()
  const res = await fetch(`${bffBaseUrl}/auth/logout`, {
    method: 'POST',
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      'x-csrf-token': csrfToken,
    },
  })
  return res.json()
}

/**
 * BFF /auth/refresh を呼び出し、トークンをリフレッシュ
 * CSRFトークンをヘッダーに付与する必要があります。
 *
 * @returns {Promise<object>} { success, message, tokenStatus? }
 */
export async function postAuthRefresh() {
  const csrfToken = getCsrfToken()
  const res = await fetch(`${bffBaseUrl}/auth/refresh`, {
    method: 'POST',
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      'x-csrf-token': csrfToken,
    },
  })
  return res.json()
}

/**
 * CSRFトークンをCookieから取得
 *
 * BFFが設定した csrf_token Cookie（HttpOnly=false）を読み取ります。
 * このトークンをリクエストヘッダーに付与することで、
 * 正規のフロントエンドからのリクエストであることを証明します。
 *
 * @returns {string} CSRFトークン
 */
function getCsrfToken() {
  const match = document.cookie.match(/(?:^|;\s*)csrf_token=([^;]*)/)
  return match ? match[1] : ''
}
