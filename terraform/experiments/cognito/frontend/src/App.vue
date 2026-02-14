<script setup>
// BFF版 App.vue
// ==============
// SPA版との主な違い:
// - コールバック処理なし（BFFが /auth/callback を直接処理）
// - トークン管理なし（sessionStorageを使わない）
// - /auth/me を呼び出して認証状態を確認
// - HttpOnly CookieのセッションIDが自動送信される

import { ref, onMounted } from 'vue'
import { fetchAuthMe, initBffConfig } from './auth/cognito.js'
import LoginButton from './components/LoginButton.vue'
import LogoutButton from './components/LogoutButton.vue'
import UserInfo from './components/UserInfo.vue'
import TokenDetails from './components/TokenDetails.vue'

const loading = ref(true)
const error = ref(null)
const authData = ref(null) // /auth/me のレスポンス

onMounted(async () => {
  try {
    // URLにエラーパラメータがある場合（BFFからのリダイレクト時）
    const params = new URLSearchParams(window.location.search)
    const urlError = params.get('error')
    if (urlError) {
      error.value = urlError
      // URLをクリーンにする（エラーパラメータを除去）
      window.history.replaceState({}, '', '/')
      loading.value = false
      return
    }

    // BFF APIのベースURLを設定（Amplifyデプロイ時はAPI Gateway URL）
    await initBffConfig()

    // BFFに認証状態を確認
    // HttpOnly CookieのセッションIDが自動送信され、
    // BFFがセッションからユーザー情報を返します。
    const data = await fetchAuthMe()
    if (data.authenticated) {
      authData.value = data
    }
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="app">
    <header>
      <h1>Cognito BFF Auth Demo</h1>
      <p class="subtitle">BFF (Backend For Frontend) × PKCE × HttpOnly Cookie</p>
    </header>

    <main>
      <!-- ローディング -->
      <div v-if="loading" class="loading">
        認証状態を確認中...
      </div>

      <!-- エラー表示 -->
      <div v-else-if="error" class="error-box">
        <h2>エラー</h2>
        <p>{{ error }}</p>
        <a href="/">ホームに戻る</a>
      </div>

      <!-- ログイン済み -->
      <div v-else-if="authData">
        <UserInfo :claims="authData.claims.idToken" />
        <TokenDetails :authData="authData" />
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
