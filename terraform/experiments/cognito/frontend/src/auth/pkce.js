// PKCE (Proof Key for Code Exchange) 手動実装
// =============================================
// RFC 7636 に基づくPKCEフローのコア関数です。
// 通常はSDK（aws-amplify等）が内部で処理しますが、
// ここでは学習のため手動で実装しています。
//
// PKCEフロー概要:
// 1. code_verifier（ランダム文字列）を生成
// 2. code_challenge = BASE64URL(SHA256(code_verifier)) を計算
// 3. code_challenge を認可リクエストに含めて送信
// 4. 認可コード受信後、code_verifier でトークンを交換
// → code_verifier を知らない第三者は認可コードを横取りしても使えない

// RFC 7636 で定義された使用可能文字
// unreserved characters: [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
const CHARSET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~'

/**
 * code_verifier を生成する
 * 暗号学的に安全な乱数から、43〜128文字のランダム文字列を生成します。
 *
 * @param {number} length - 文字列長（デフォルト: 64, RFC 7636では43-128）
 * @returns {string} code_verifier
 */
export function generateCodeVerifier(length = 64) {
  const array = new Uint8Array(length)
  crypto.getRandomValues(array)
  return Array.from(array, (byte) => CHARSET[byte % CHARSET.length]).join('')
}

/**
 * code_verifier から code_challenge を生成する
 * SHA-256ハッシュを計算し、Base64URL エンコードします。
 *
 * code_challenge = BASE64URL(SHA256(code_verifier))
 *
 * @param {string} codeVerifier - generateCodeVerifier()で生成した値
 * @returns {Promise<string>} code_challenge（Base64URL形式）
 */
export async function generateCodeChallenge(codeVerifier) {
  const encoder = new TextEncoder()
  const data = encoder.encode(codeVerifier)

  // Web Crypto API で SHA-256 ハッシュを計算
  const digest = await crypto.subtle.digest('SHA-256', data)

  // ArrayBuffer → Base64URL 変換
  // 標準のBase64から、URLセーフな文字に変換し、パディングを除去
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, '-')  // '+' → '-'
    .replace(/\//g, '_')  // '/' → '_'
    .replace(/=+$/, '')   // 末尾の '=' を除去
}
