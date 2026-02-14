// Lambda ハンドラー
// ================
// serverless-http でExpressアプリをLambda互換にラップします。
// API Gateway HTTP API (v2) イベントを処理します。
//
// serverless-http の役割:
// - API Gateway イベント → Express req オブジェクトに変換
// - Express res オブジェクト → API Gateway レスポンスに変換
// - Cookie、リダイレクト、JSONレスポンスが全てそのまま動作
//
// ローカル開発では server.js を使用します（app.listen() で起動）。
// Lambda環境ではこのファイルの handler をエントリーポイントとして使用します。

import serverless from 'serverless-http'
import express from 'express'
import cookieParser from 'cookie-parser'
import cors from 'cors'
import { loadConfig } from './config.js'
import { authRouter } from './auth/routes.js'

const config = loadConfig()
const app = express()

// ========================================
// ミドルウェア設定（server.jsと同じ構成）
// ========================================

app.use(cookieParser())
app.use(express.json())

// CORS設定
// Lambda環境ではフロントエンド（Amplify）と異なるドメインのため、
// credentials: true でクロスオリジンCookieの送受信を許可
app.use(cors({
  origin: config.frontendOrigin,
  credentials: true,
}))

// ========================================
// ルート
// ========================================

app.use('/auth', authRouter(config))

app.get('/health', (req, res) => {
  res.json({ status: 'ok', runtime: 'lambda' })
})

// ========================================
// Lambda ハンドラー
// ========================================

export const handler = serverless(app)
