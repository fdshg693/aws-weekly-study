<script setup>
import { ref, onMounted } from 'vue'
import { loadConfig, exchangeCodeForTokens } from './auth/cognito.js'
import {
  saveTokens,
  getTokens,
  getCodeVerifier,
  clearCodeVerifier,
  decodeJwtPayload,
} from './auth/tokenStore.js'
import LoginButton from './components/LoginButton.vue'
import LogoutButton from './components/LogoutButton.vue'
import UserInfo from './components/UserInfo.vue'
import TokenDetails from './components/TokenDetails.vue'

const loading = ref(true)
const error = ref(null)
const tokens = ref(null)
const idTokenClaims = ref(null)
const accessTokenClaims = ref(null)

onMounted(async () => {
  try {
    const path = window.location.pathname

    // コールバック処理: /callback?code=xxx
    if (path === '/callback') {
      await handleCallback()
      return
    }

    // 通常表示: 保存済みトークンを確認
    checkExistingTokens()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

/**
 * コールバック処理
 * 1. URLからcodeパラメータを取得
 * 2. sessionStorageからcode_verifierを取得
 * 3. code + code_verifier でトークンを交換
 * 4. トークンを保存してホームにリダイレクト
 */
async function handleCallback() {
  const params = new URLSearchParams(window.location.search)
  const code = params.get('code')
  const callbackError = params.get('error')

  if (callbackError) {
    const errorDescription = params.get('error_description') || callbackError
    throw new Error(`認証エラー: ${errorDescription}`)
  }

  if (!code) {
    throw new Error('認可コードが見つかりません')
  }

  const codeVerifier = getCodeVerifier()
  if (!codeVerifier) {
    throw new Error('code_verifierが見つかりません（セッションが切れた可能性があります）')
  }

  // トークン交換
  const config = await loadConfig()
  const tokenResponse = await exchangeCodeForTokens(config, code, codeVerifier)

  // 保存 & クリーンアップ
  saveTokens(tokenResponse)
  clearCodeVerifier()

  // ホームにリダイレクト（URLをきれいにする）
  window.location.replace('/')
}

function checkExistingTokens() {
  const stored = getTokens()
  if (stored.idToken && stored.accessToken) {
    tokens.value = stored
    idTokenClaims.value = decodeJwtPayload(stored.idToken)
    accessTokenClaims.value = decodeJwtPayload(stored.accessToken)
  }
}
</script>

<template>
  <div class="app">
    <header>
      <h1>Cognito PKCE Auth Demo</h1>
      <p class="subtitle">手動PKCE実装 × Hosted UI × Amplify Hosting</p>
    </header>

    <main>
      <!-- ローディング -->
      <div v-if="loading" class="loading">
        トークンを処理中...
      </div>

      <!-- エラー表示 -->
      <div v-else-if="error" class="error-box">
        <h2>エラー</h2>
        <p>{{ error }}</p>
        <a href="/">ホームに戻る</a>
      </div>

      <!-- ログイン済み -->
      <div v-else-if="tokens">
        <UserInfo :claims="idTokenClaims" />
        <TokenDetails
          :tokens="tokens"
          :idTokenClaims="idTokenClaims"
          :accessTokenClaims="accessTokenClaims"
        />
        <div class="actions">
          <LogoutButton />
        </div>
      </div>

      <!-- 未ログイン -->
      <div v-else>
        <LoginButton />
      </div>
    </main>
  </div>
</template>

<style scoped>
.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

header {
  text-align: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 2px solid #e9ecef;
}

header h1 {
  margin-bottom: 0.3rem;
  color: #212529;
}

.subtitle {
  color: #6c757d;
  font-size: 0.95rem;
}

.loading {
  text-align: center;
  padding: 3rem;
  color: #6c757d;
}

.error-box {
  background: #f8d7da;
  color: #721c24;
  padding: 1.5rem;
  border-radius: 8px;
}

.error-box a {
  color: #721c24;
  font-weight: 600;
}

.actions {
  text-align: center;
  margin-top: 1.5rem;
}
</style>
