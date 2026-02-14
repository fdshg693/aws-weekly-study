<script setup>
// BFF版: ログアウトはBFF APIを呼び出してセッションを破棄し、
// Cognito Hosted UIのログアウトURLにリダイレクトします。
//
// SPA版との違い:
// - SPA版: sessionStorage.clear() → Cognitoログアウト
// - BFF版: POST /auth/logout（セッション破棄）→ Cognitoログアウト

import { postAuthLogout } from '../auth/cognito.js'

async function handleLogout() {
  // 1. BFFにログアウトリクエスト
  //    → サーバーサイドセッション削除 + Cookie クリア
  const { logoutUrl } = await postAuthLogout()

  // 2. Cognitoのログアウトエンドポイントにリダイレクト
  //    → Cognito Hosted UIのセッションCookieも無効化
  window.location.href = logoutUrl
}
</script>

<template>
  <button class="btn btn-danger" @click="handleLogout">
    ログアウト
  </button>
</template>
