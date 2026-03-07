<script setup>
// BFF版 TokenDetails
// ==================
// SPA版ではトークン本体（JWT文字列）を表示していましたが、
// BFF版ではトークンはサーバーサイドにのみ存在します。
// ブラウザに返されるのはデコード済みのクレーム情報のみです。
//
// props:
// - authData: /auth/me レスポンス
//   { authenticated, user, claims: { idToken, accessToken }, tokenStatus }

import { computed, ref } from 'vue'
import { postAuthRefresh } from '../auth/cognito.js'

const props = defineProps({
  authData: {
    type: Object,
    required: true,
  },
})

const refreshing = ref(false)
const refreshResult = ref(null)

function isExpired(claims) {
  if (!claims.exp) return false
  return Date.now() > claims.exp * 1000
}

const idTokenExpired = computed(() => isExpired(props.authData.claims.idToken))
const accessTokenExpired = computed(() => isExpired(props.authData.claims.accessToken))

async function handleRefresh() {
  refreshing.value = true
  refreshResult.value = null
  try {
    const result = await postAuthRefresh()
    if (result.success) {
      refreshResult.value = {
        type: 'success',
        message: `リフレッシュ成功！新しい有効期限: ${new Date(result.tokenStatus.accessTokenExpiresAt).toLocaleString('ja-JP')}`,
      }
    } else {
      refreshResult.value = { type: 'error', message: result.message }
    }
  } catch (e) {
    refreshResult.value = { type: 'error', message: e.message }
  } finally {
    refreshing.value = false
  }
}
</script>

<template>
  <div class="token-details">
    <h2>トークン詳細（BFFサーバーサイド）</h2>
    <p class="security-note">
      トークン本体はBFFサーバーに保管されています。
      ブラウザにはセッションCookie（HttpOnly）のみ存在します。
    </p>

    <!-- ID Token Claims -->
    <div class="token-section">
      <h3>
        ID Token Claims
        <span :class="['badge', idTokenExpired ? 'badge-expired' : 'badge-valid']">
          {{ idTokenExpired ? '期限切れ' : '有効' }}
        </span>
      </h3>
      <details>
        <summary>デコード済みペイロード（サーバーで署名検証済み）</summary>
        <pre>{{ JSON.stringify(authData.claims.idToken, null, 2) }}</pre>
      </details>
    </div>

    <!-- Access Token Claims -->
    <div class="token-section">
      <h3>
        Access Token Claims
        <span :class="['badge', accessTokenExpired ? 'badge-expired' : 'badge-valid']">
          {{ accessTokenExpired ? '期限切れ' : '有効' }}
        </span>
      </h3>
      <details>
        <summary>デコード済みペイロード（サーバーで署名検証済み）</summary>
        <pre>{{ JSON.stringify(authData.claims.accessToken, null, 2) }}</pre>
      </details>
    </div>

    <!-- Token Status -->
    <div class="token-section">
      <h3>トークンステータス</h3>
      <table>
        <tbody>
          <tr>
            <th>アクセストークン有効期限</th>
            <td>{{ new Date(authData.tokenStatus.accessTokenExpiresAt).toLocaleString('ja-JP') }}</td>
          </tr>
          <tr>
            <th>アクセストークン状態</th>
            <td>
              <span :class="['badge', authData.tokenStatus.accessTokenExpired ? 'badge-expired' : 'badge-valid']">
                {{ authData.tokenStatus.accessTokenExpired ? '期限切れ' : '有効' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Refresh Button -->
    <div class="token-section">
      <h3>トークンリフレッシュ</h3>
      <p class="token-note">
        アクセストークンの有効期限（1時間）が切れた場合、
        リフレッシュトークン（30日）を使って新しいトークンを取得します。
      </p>
      <button class="btn" @click="handleRefresh" :disabled="refreshing">
        {{ refreshing ? 'リフレッシュ中...' : 'トークンをリフレッシュ' }}
      </button>
      <div v-if="refreshResult" :class="['refresh-result', `refresh-${refreshResult.type}`]">
        {{ refreshResult.message }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.token-details {
  margin-bottom: 1.5rem;
}

.security-note {
  background: #d4edda;
  color: #155724;
  padding: 0.8rem 1rem;
  border-radius: 6px;
  font-size: 0.9em;
  margin-bottom: 1rem;
}

.token-section {
  background: #f8f9fa;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  margin-bottom: 1rem;
}

.token-section h3 {
  margin-top: 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.badge {
  font-size: 0.75rem;
  padding: 0.2rem 0.6rem;
  border-radius: 12px;
  font-weight: 500;
}

.badge-valid {
  background: #d4edda;
  color: #155724;
}

.badge-expired {
  background: #f8d7da;
  color: #721c24;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 0.5rem;
  text-align: left;
  border-bottom: 1px solid #dee2e6;
}

th {
  width: 200px;
  color: #495057;
  font-weight: 600;
}

details {
  margin-top: 0.5rem;
}

summary {
  cursor: pointer;
  color: #007bff;
  font-size: 0.9em;
}

pre {
  background: #212529;
  color: #f8f9fa;
  padding: 1rem;
  border-radius: 6px;
  overflow-x: auto;
  font-size: 0.8em;
  line-height: 1.5;
}

.token-note {
  font-size: 0.85em;
  color: #6c757d;
}

.btn {
  margin-top: 0.5rem;
}

.refresh-result {
  margin-top: 0.5rem;
  padding: 0.5rem 0.8rem;
  border-radius: 4px;
  font-size: 0.9em;
}

.refresh-success {
  background: #d4edda;
  color: #155724;
}

.refresh-error {
  background: #f8d7da;
  color: #721c24;
}
</style>
