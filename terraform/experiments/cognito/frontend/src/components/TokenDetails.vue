<script setup>
import { computed } from 'vue'

const props = defineProps({
  tokens: {
    type: Object,
    required: true,
  },
  idTokenClaims: {
    type: Object,
    required: true,
  },
  accessTokenClaims: {
    type: Object,
    required: true,
  },
})

function truncateToken(token, length = 50) {
  if (!token) return 'N/A'
  if (token.length <= length) return token
  return token.substring(0, length) + '...'
}

function isExpired(claims) {
  if (!claims.exp) return false
  return Date.now() > claims.exp * 1000
}

const idTokenExpired = computed(() => isExpired(props.idTokenClaims))
const accessTokenExpired = computed(() => isExpired(props.accessTokenClaims))
</script>

<template>
  <div class="token-details">
    <h2>トークン詳細</h2>

    <!-- ID Token -->
    <div class="token-section">
      <h3>
        ID Token
        <span :class="['badge', idTokenExpired ? 'badge-expired' : 'badge-valid']">
          {{ idTokenExpired ? '期限切れ' : '有効' }}
        </span>
      </h3>
      <div class="token-raw">
        <code>{{ truncateToken(tokens.idToken, 80) }}</code>
      </div>
      <details>
        <summary>デコード済みペイロード</summary>
        <pre>{{ JSON.stringify(idTokenClaims, null, 2) }}</pre>
      </details>
    </div>

    <!-- Access Token -->
    <div class="token-section">
      <h3>
        Access Token
        <span :class="['badge', accessTokenExpired ? 'badge-expired' : 'badge-valid']">
          {{ accessTokenExpired ? '期限切れ' : '有効' }}
        </span>
      </h3>
      <div class="token-raw">
        <code>{{ truncateToken(tokens.accessToken, 80) }}</code>
      </div>
      <details>
        <summary>デコード済みペイロード</summary>
        <pre>{{ JSON.stringify(accessTokenClaims, null, 2) }}</pre>
      </details>
    </div>

    <!-- Refresh Token -->
    <div v-if="tokens.refreshToken" class="token-section">
      <h3>Refresh Token</h3>
      <div class="token-raw">
        <code>{{ truncateToken(tokens.refreshToken, 80) }}</code>
      </div>
      <p class="token-note">
        ※ Refresh Tokenは暗号化されているためデコード不可
      </p>
    </div>
  </div>
</template>

<style scoped>
.token-details {
  margin-bottom: 1.5rem;
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

.token-raw {
  margin: 0.5rem 0;
}

.token-raw code {
  background: #e9ecef;
  padding: 0.3rem 0.6rem;
  border-radius: 4px;
  font-size: 0.8em;
  word-break: break-all;
  display: block;
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
  margin-bottom: 0;
}
</style>
