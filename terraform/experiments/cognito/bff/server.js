// BFF (Backend For Frontend) サーバー
// ====================================
// Express.jsを使ったBFFサーバーです。
// フロントエンド（Vue SPA）とCognito間の認証を仲介します。
//
// BFFパターンの利点:
// - トークンがブラウザに露出しない（XSS対策の根本解決）
// - HttpOnly Cookieでセッション管理（JavaScriptからアクセス不可）
// - client_secretをサーバーサイドで安全に使用可能
// - JWT署名検証、state、nonce検証をサーバーサイドで完結
// - CSRF保護をDouble Submit Cookieパターンで実装

import express from 'express'
import cookieParser from 'cookie-parser'
import cors from 'cors'
import { loadConfig } from './config.js'
import { authRouter } from './auth/routes.js'

const config = loadConfig()
const app = express()

// ========================================
// ミドルウェア設定
// ========================================

// Cookie解析
app.use(cookieParser())

// JSONボディ解析
app.use(express.json())

// CORS設定
// Vite開発サーバー（localhost:5173）からのリクエストを許可
// credentials: true でCookieの送受信を有効化
app.use(cors({
  origin: config.frontendOrigin,
  credentials: true,
}))

// ========================================
// ルート
// ========================================

// 認証ルート（/auth/*）
app.use('/auth', authRouter(config))

// ヘルスチェック
app.get('/health', (req, res) => {
  res.json({ status: 'ok' })
})

// ========================================
// サーバー起動
// ========================================

const PORT = process.env.PORT || 3000
app.listen(PORT, () => {
  console.log(`BFF server running on http://localhost:${PORT}`)
  console.log(`Frontend origin: ${config.frontendOrigin}`)
  console.log(`Cognito domain: ${config.cognitoDomain}`)
  console.log(`Redirect URI: ${config.redirectUri}`)
})
