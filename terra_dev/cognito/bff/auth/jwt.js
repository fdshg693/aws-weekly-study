// JWT検証（JWKSベース）
// =====================
// Cognito が発行したJWTトークンの署名を検証します。
//
// なぜ署名検証が必要か:
// JWTは3つのパーツ（header.payload.signature）で構成されます。
// SPA版（脆弱性#3）ではpayloadをBase64デコードするだけで署名を無視していたため、
// 攻撃者が偽のJWTを作成できました。
// サーバーサイドでJWKS公開鍵を使って署名を検証することで、
// Cognitoが発行した正規のトークンのみを受け入れます。
//
// JWKSとは:
// - JSON Web Key Set: JWTの署名検証に使う公開鍵のセット
// - Cognitoの公開URL: https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/jwks.json
// - 鍵はローテーションされるため、joseライブラリが自動的にキャッシュ・再取得
//
// 検証項目:
// ┌──────────────┬──────────────────────────────────────────────────────┐
// │ 検証項目      │ 目的                                                │
// ├──────────────┼──────────────────────────────────────────────────────┤
// │ 署名 (RS256) │ トークンが改ざんされていないことを確認               │
// │ exp          │ トークンが有効期限内であることを確認                 │
// │ iss          │ 発行者が正しいCognito User Poolであることを確認      │
// │ aud          │ 対象クライアントが正しいことを確認（IDトークンのみ） │
// │ token_use    │ トークンの種類（id/access）が期待通りであることを確認│
// │ nonce        │ リプレイ攻撃でないことを確認（IDトークンのみ）       │
// └──────────────┴──────────────────────────────────────────────────────┘

import { createRemoteJWKSet, jwtVerify } from 'jose'

// JWKSクライアントのキャッシュ（User Pool毎に1つ）
let jwks = null

/**
 * JWKSクライアントを取得（遅延初期化 + キャッシュ）
 * createRemoteJWKSet は内部でHTTPキャッシュを管理し、
 * 鍵のローテーション時に自動的に再取得します。
 */
function getJwks(config) {
  if (!jwks) {
    const jwksUrl = new URL(
      `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}/.well-known/jwks.json`
    )
    jwks = createRemoteJWKSet(jwksUrl)
  }
  return jwks
}

/**
 * IDトークンを検証
 *
 * IDトークン固有の検証:
 * - aud（audience）= clientId であること
 * - token_use = "id" であること
 * - nonce が期待値と一致すること（初回検証時）
 *
 * @param {object} config - BFF設定
 * @param {string} token - JWT文字列
 * @param {string|null} expectedNonce - 期待するnonce値（コールバック時に指定）
 * @returns {Promise<object>} 検証済みペイロード（claims）
 */
export async function verifyIdToken(config, token, expectedNonce = null) {
  const { payload } = await jwtVerify(token, getJwks(config), {
    issuer: `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}`,
    audience: config.clientId,
  })

  // token_use の検証
  // IDトークンとアクセストークンを取り違えていないか確認
  if (payload.token_use !== 'id') {
    throw new Error(`Invalid token_use: expected "id", got "${payload.token_use}"`)
  }

  // nonce の検証（リプレイ攻撃防止）
  // コールバック時にのみ検証。/auth/meでの再検証時はスキップ。
  if (expectedNonce && payload.nonce !== expectedNonce) {
    throw new Error('nonce mismatch: IDトークンのリプレイ攻撃の可能性があります')
  }

  return payload
}

/**
 * アクセストークンを検証
 *
 * Cognitoのアクセストークン固有の注意点:
 * - aud claimが含まれない（Cognito仕様）
 *   → audienceオプションを指定しない
 * - client_id claimは含まれる
 *   → token_use = "access" で判別
 *
 * @param {object} config - BFF設定
 * @param {string} token - JWT文字列
 * @returns {Promise<object>} 検証済みペイロード（claims）
 */
export async function verifyAccessToken(config, token) {
  const { payload } = await jwtVerify(token, getJwks(config), {
    issuer: `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}`,
  })

  if (payload.token_use !== 'access') {
    throw new Error(`Invalid token_use: expected "access", got "${payload.token_use}"`)
  }

  return payload
}
