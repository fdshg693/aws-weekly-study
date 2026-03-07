// ===================================================================
// NOTE: このファイルはBFF版では使用されません。
// トークンはBFFサーバーのメモリ上にのみ保存されます。
// sessionStorageベースの管理は不要です。
// SPA直接認証（BFFなし）の参考コードとして残しています。
// ===================================================================

// Token Store
// ===========
// sessionStorageを使ったトークン管理です。
// sessionStorageはタブを閉じるとクリアされるため、
// デモ用途に適しています（localStorageより安全）。

const KEYS = {
  accessToken: 'cognito_access_token',
  idToken: 'cognito_id_token',
  refreshToken: 'cognito_refresh_token',
  codeVerifier: 'pkce_code_verifier',
}

/**
 * トークンレスポンスをsessionStorageに保存
 * @param {{ access_token: string, id_token: string, refresh_token?: string }} tokenResponse
 */
export function saveTokens(tokenResponse) {
  sessionStorage.setItem(KEYS.accessToken, tokenResponse.access_token)
  sessionStorage.setItem(KEYS.idToken, tokenResponse.id_token)
  if (tokenResponse.refresh_token) {
    sessionStorage.setItem(KEYS.refreshToken, tokenResponse.refresh_token)
  }
}

/**
 * 保存済みトークンを取得
 * @returns {{ accessToken: string|null, idToken: string|null, refreshToken: string|null }}
 */
export function getTokens() {
  return {
    accessToken: sessionStorage.getItem(KEYS.accessToken),
    idToken: sessionStorage.getItem(KEYS.idToken),
    refreshToken: sessionStorage.getItem(KEYS.refreshToken),
  }
}

/**
 * すべてのトークンをクリア
 */
export function clearTokens() {
  sessionStorage.removeItem(KEYS.accessToken)
  sessionStorage.removeItem(KEYS.idToken)
  sessionStorage.removeItem(KEYS.refreshToken)
}

/**
 * PKCE code_verifier を一時保存（認可リダイレクト前に保存し、コールバックで取得）
 */
export function saveCodeVerifier(verifier) {
  sessionStorage.setItem(KEYS.codeVerifier, verifier)
}

export function getCodeVerifier() {
  return sessionStorage.getItem(KEYS.codeVerifier)
}

export function clearCodeVerifier() {
  sessionStorage.removeItem(KEYS.codeVerifier)
}

/**
 * JWTトークンのペイロード部分をデコード
 * JWTは header.payload.signature の3パートで構成されています。
 *
 * @param {string} token - JWT文字列
 * @returns {object} デコードされたペイロード
 */
export function decodeJwtPayload(token) {
  const base64Url = token.split('.')[1]
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
  const jsonPayload = decodeURIComponent(
    atob(base64)
      .split('')
      .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
      .join('')
  )
  return JSON.parse(jsonPayload)
}
