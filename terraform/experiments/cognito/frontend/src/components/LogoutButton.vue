<script setup>
import { loadConfig, getLogoutUrl } from '../auth/cognito.js'
import { clearTokens } from '../auth/tokenStore.js'

async function handleLogout() {
  // 1. sessionStorageからトークンをクリア
  clearTokens()

  // 2. Hosted UI のログアウトエンドポイントにリダイレクト
  //    Cognitoセッションも無効化されます
  const config = await loadConfig()
  window.location.href = getLogoutUrl(config)
}
</script>

<template>
  <button class="btn btn-danger" @click="handleLogout">
    ログアウト
  </button>
</template>
