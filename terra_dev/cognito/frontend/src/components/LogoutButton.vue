<script setup>
// BFF版: ログアウトはBFF APIを呼び出してセッションを破棄し、
// Cognito Hosted UIのログアウトURLにリダイレクトします。
//
// SPA版との違い:
// - SPA版: sessionStorage.clear() → Cognitoログアウト
// - BFF版: POST /auth/logout（セッション破棄）→ Cognitoログアウト

import { postAuthLogout } from '../auth/cognito.js'

async function handleLogout() {
  try {
    // 1. BFFにログアウトリクエスト
    //    → サーバーサイドセッション削除 + Cookie クリア
    const data = await postAuthLogout()

    if (!data.logoutUrl) {
      console.error('[LOGOUT] BFF error:', data)
      alert('ログアウトに失敗しました: ' + (data.message || 'Unknown error'))
      return
    }

    // 2. Cognitoのログアウトエンドポイントにリダイレクト
    //    → Cognito Hosted UIのセッションCookieも無効化
    window.location.href = data.logoutUrl
  } catch (err) {
    console.error('[LOGOUT] Error:', err)
    alert('ログアウトに失敗しました: ' + err.message)
  }
}
</script>

<template>
  <button class="btn btn-danger" @click="handleLogout">
    ログアウト
  </button>
</template>
