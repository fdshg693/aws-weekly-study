<script setup>
import { loadConfig, getAuthorizeUrl } from '../auth/cognito.js'
import { generateCodeVerifier, generateCodeChallenge } from '../auth/pkce.js'
import { saveCodeVerifier } from '../auth/tokenStore.js'

async function handleLogin() {
  // 1. code_verifier を生成（ランダム64文字）
  const codeVerifier = generateCodeVerifier()

  // 2. code_challenge を計算（SHA-256 → Base64URL）
  const codeChallenge = await generateCodeChallenge(codeVerifier)

  // 3. code_verifier をsessionStorageに保存（コールバック時に使用）
  saveCodeVerifier(codeVerifier)

  // 4. Hosted UI の認可エンドポイントにリダイレクト
  const config = await loadConfig()
  const authorizeUrl = getAuthorizeUrl(config, codeChallenge)
  window.location.href = authorizeUrl
}
</script>

<template>
  <div class="login-section">
    <p>Cognito Hosted UI を使ったPKCE認証フローのデモです。</p>
    <button class="btn btn-primary" @click="handleLogin">
      ログイン（Hosted UI）
    </button>
    <div class="flow-description">
      <h3>PKCEフローの流れ</h3>
      <ol>
        <li><code>code_verifier</code>（ランダム文字列）を生成</li>
        <li><code>code_challenge = BASE64URL(SHA256(code_verifier))</code> を計算</li>
        <li><code>code_challenge</code> 付きで Hosted UI にリダイレクト</li>
        <li>ログイン後、認可コード付きでコールバック</li>
        <li>認可コード + <code>code_verifier</code> でトークン取得</li>
      </ol>
    </div>
  </div>
</template>

<style scoped>
.login-section {
  text-align: center;
}

.flow-description {
  margin-top: 2rem;
  text-align: left;
  background: #f8f9fa;
  padding: 1.5rem;
  border-radius: 8px;
}

.flow-description h3 {
  margin-top: 0;
  color: #495057;
}

.flow-description ol {
  line-height: 1.8;
}

.flow-description code {
  background: #e9ecef;
  padding: 0.15rem 0.4rem;
  border-radius: 3px;
  font-size: 0.9em;
}
</style>
