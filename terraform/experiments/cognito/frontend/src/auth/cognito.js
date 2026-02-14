// Cognito OAuth Helper
// ====================
// Cognito Hosted UI の OAuth エンドポイントと通信するヘルパー関数です。
// aws-amplify SDK を使わず、fetch API で直接通信します。
//
// エンドポイント一覧:
// - /oauth2/authorize - 認可エンドポイント（ブラウザリダイレクト）
// - /oauth2/token     - トークンエンドポイント（POST）
// - /logout           - ログアウトエンドポイント（ブラウザリダイレクト）

let config = null

/**
 * Cognito設定を読み込む
 * 1. /config.json（Terraform生成）を試行
 * 2. 失敗した場合はVite環境変数にフォールバック
 *
 * @returns {Promise<object>} Cognito設定オブジェクト
 */
export async function loadConfig() {
  if (config) return config

  try {
    const res = await fetch('/config.json')
    if (res.ok) {
      config = await res.json()
      // redirectUri/logoutUri が未設定の場合、現在のオリジンから生成
      if (!config.redirectUri) {
        config.redirectUri = `${window.location.origin}/callback`
      }
      if (!config.logoutUri) {
        config.logoutUri = `${window.location.origin}/`
      }
      return config
    }
  } catch {
    // config.json が存在しない場合（ローカル開発時など）
  }

  // Vite環境変数にフォールバック
  config = {
    region: import.meta.env.VITE_COGNITO_REGION,
    userPoolId: import.meta.env.VITE_USER_POOL_ID,
    clientId: import.meta.env.VITE_CLIENT_ID,
    cognitoDomain: import.meta.env.VITE_COGNITO_DOMAIN,
    redirectUri: import.meta.env.VITE_REDIRECT_URI || `${window.location.origin}/callback`,
    logoutUri: import.meta.env.VITE_LOGOUT_URI || `${window.location.origin}/`,
  }
  return config
}

/**
 * Hosted UI の認可URLを生成
 * PKCEのcode_challengeを含めてリダイレクトします。
 *
 * @param {object} cfg - loadConfig()の戻り値
 * @param {string} codeChallenge - generateCodeChallenge()で生成した値
 * @returns {string} 認可エンドポイントのURL
 */
export function getAuthorizeUrl(cfg, codeChallenge) {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: cfg.clientId,
    redirect_uri: cfg.redirectUri,
    scope: 'openid email profile',
    code_challenge_method: 'S256',
    code_challenge: codeChallenge,
  })
  return `https://${cfg.cognitoDomain}/oauth2/authorize?${params}`
}

/**
 * 認可コードをトークンに交換する
 * PKCEのcode_verifierを添えてPOSTリクエストを送信します。
 *
 * Cognito /oauth2/token エンドポイントは
 * application/x-www-form-urlencoded 形式のみ受け付けます。
 *
 * @param {object} cfg - loadConfig()の戻り値
 * @param {string} code - コールバックURLのcodeパラメータ
 * @param {string} codeVerifier - 認可リクエスト前に保存したcode_verifier
 * @returns {Promise<object>} { access_token, id_token, refresh_token, token_type, expires_in }
 */
export async function exchangeCodeForTokens(cfg, code, codeVerifier) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: cfg.clientId,
    code,
    redirect_uri: cfg.redirectUri,
    code_verifier: codeVerifier,
  })

  const response = await fetch(`https://${cfg.cognitoDomain}/oauth2/token`, {
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
 * Hosted UI のログアウトURLを生成
 * ログアウト後、logout_uriにリダイレクトされます。
 *
 * @param {object} cfg - loadConfig()の戻り値
 * @returns {string} ログアウトエンドポイントのURL
 */
export function getLogoutUrl(cfg) {
  const params = new URLSearchParams({
    client_id: cfg.clientId,
    logout_uri: cfg.logoutUri,
  })
  return `https://${cfg.cognitoDomain}/logout?${params}`
}
