// BFF設定管理
// ===========
// Terraform生成のconfig.jsonまたは環境変数から設定を読み込みます。
//
// 設定項目:
// - region: AWSリージョン
// - userPoolId: Cognito User Pool ID
// - clientId: Cognito Client ID
// - clientSecret: Cognito Client Secret（機密情報）
// - cognitoDomain: Hosted UIドメイン
// - redirectUri: BFFのコールバックURL
// - logoutUri: ログアウト後のリダイレクト先
// - frontendOrigin: フロントエンドのオリジン（CORS/リダイレクト用）

import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

export function loadConfig() {
  const __dirname = dirname(fileURLToPath(import.meta.url))

  let fileConfig = {}
  try {
    const raw = readFileSync(join(__dirname, 'config.json'), 'utf-8')
    fileConfig = JSON.parse(raw)
  } catch {
    console.log('config.json not found, using environment variables')
  }

  return {
    region: fileConfig.region || process.env.COGNITO_REGION,
    userPoolId: fileConfig.userPoolId || process.env.USER_POOL_ID,
    clientId: fileConfig.clientId || process.env.CLIENT_ID,
    clientSecret: fileConfig.clientSecret || process.env.CLIENT_SECRET,
    cognitoDomain: fileConfig.cognitoDomain || process.env.COGNITO_DOMAIN,
    redirectUri: fileConfig.redirectUri || process.env.REDIRECT_URI || 'http://localhost:3000/auth/callback',
    logoutUri: fileConfig.logoutUri || process.env.LOGOUT_URI || 'http://localhost:3000/',
    frontendOrigin: process.env.FRONTEND_ORIGIN || 'http://localhost:5173',
  }
}
