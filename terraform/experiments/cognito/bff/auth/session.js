// セッション管理
// ===============
// ストア抽象化を通じてセッションの作成・取得・更新・削除を行います。
//
// ストアの切り替え:
// - ローカル開発: インメモリMap（SESSION_STORE_TYPE=memory または未設定）
// - Lambda環境:   DynamoDB（SESSION_STORE_TYPE=dynamodb）
//
// セッションの仕組み:
// 1. ログイン成功時にランダムなセッションID（64文字hex）を生成
// 2. セッションIDをHttpOnly Cookieに設定（ブラウザ↔BFF間）
// 3. トークンはストアにのみ保存（ブラウザには送らない）
//
// HttpOnly Cookieの特性:
// - JavaScriptからアクセス不可（document.cookieで読めない）
// - XSS攻撃でトークンが盗まれるリスクを排除
// - ブラウザが自動的にリクエストに付与
//
// 比較: sessionStorage（SPA版）vs HttpOnly Cookie（BFF版）
// ┌────────────────────┬───────────────────────┬──────────────────────────┐
// │                    │ sessionStorage        │ HttpOnly Cookie          │
// ├────────────────────┼───────────────────────┼──────────────────────────┤
// │ XSS耐性           │ ✗ JSで読み取り可能    │ ○ JSからアクセス不可     │
// │ CSRF耐性          │ ○ 自動送信されない    │ △ 自動送信される→要対策  │
// │ タブ間共有        │ ✗ タブごとに独立      │ ○ 同一ドメインで共有     │
// │ サーバー側制御    │ ✗ クライアント依存    │ ○ サーバーで無効化可能   │
// └────────────────────┴───────────────────────┴──────────────────────────┘

import crypto from 'crypto'
import { getStore } from './sessionStore.js'

// セッションの最大有効期間（24時間）
const SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000
const SESSION_TTL_SECONDS = 24 * 60 * 60

// セッションキーのプレフィックス（DynamoDBで他データと区別するため）
const SESSION_PREFIX = 'session:'

/**
 * 新しいセッションを作成
 * @param {object} data - セッションに保存するデータ（tokens, claims等）
 * @returns {Promise<string>} セッションID（64文字hex）
 */
export async function createSession(data) {
  // crypto.randomBytesは暗号論的に安全な乱数を生成
  // 32バイト = 256ビットのエントロピー（ブルートフォース不可能）
  const sessionId = crypto.randomBytes(32).toString('hex')
  const store = getStore()
  await store.put(`${SESSION_PREFIX}${sessionId}`, data, SESSION_TTL_SECONDS)
  return sessionId
}

/**
 * セッションIDからセッションデータを取得
 * 存在しない場合はnullを返します。
 * TTLチェックはストア側で行われます。
 */
export async function getSession(sessionId) {
  if (!sessionId) return null
  const store = getStore()
  return store.get(`${SESSION_PREFIX}${sessionId}`)
}

/**
 * セッションデータを更新（トークンリフレッシュ時に使用）
 */
export async function updateSession(sessionId, data) {
  const store = getStore()
  return store.update(`${SESSION_PREFIX}${sessionId}`, data)
}

/**
 * セッションを削除（ログアウト時に使用）
 */
export async function deleteSession(sessionId) {
  const store = getStore()
  await store.delete(`${SESSION_PREFIX}${sessionId}`)
}

// ========================================
// 認可フロー一時データ
// ========================================
// /auth/login で生成した PKCE code_verifier、nonce を
// /auth/callback まで保持するための一時ストレージ。
// stateパラメータをキーにして保存します。

const PENDING_PREFIX = 'pending:'
const PENDING_TTL_SECONDS = 5 * 60 // 5分

/**
 * 認可フロー一時データを保存
 * @param {string} state - stateパラメータ（キー）
 * @param {object} data - { codeVerifier, nonce }
 */
export async function savePendingAuthorization(state, data) {
  const store = getStore()
  await store.put(`${PENDING_PREFIX}${state}`, data, PENDING_TTL_SECONDS)
}

/**
 * 認可フロー一時データを取得・削除（ワンタイム使用）
 * @param {string} state - stateパラメータ
 * @returns {Promise<object|null>} { codeVerifier, nonce } or null
 */
export async function consumePendingAuthorization(state) {
  const store = getStore()
  const data = await store.get(`${PENDING_PREFIX}${state}`)
  if (data) {
    await store.delete(`${PENDING_PREFIX}${state}`)
  }
  return data
}

/**
 * HttpOnly Cookie の設定オプション
 *
 * 各オプションの意味:
 * - httpOnly: true   → document.cookieでアクセス不可（XSS対策の要）
 * - secure: true     → HTTPS接続でのみCookieを送信
 * - sameSite         → ローカル開発: 'lax'、Lambda: 'none'（クロスオリジン対応）
 * - path: '/'        → 全パスで有効
 * - maxAge           → Cookieの有効期間（ミリ秒）
 *
 * Lambda環境（API Gateway）ではフロントエンド（Amplify）と異なるドメインになるため、
 * SameSite=None + Secure=true が必要です。
 * SameSite=None のCookieはSecure属性が必須（HTTPS必須）です。
 */
export function getSessionCookieOptions() {
  const isLambda = !!process.env.AWS_LAMBDA_FUNCTION_NAME
  return {
    httpOnly: true,
    secure: isLambda || process.env.NODE_ENV === 'production',
    sameSite: isLambda ? 'none' : 'lax',
    maxAge: SESSION_MAX_AGE_MS,
    path: '/',
  }
}

// Cookie名の定数
export const SESSION_COOKIE_NAME = 'bff_session'
