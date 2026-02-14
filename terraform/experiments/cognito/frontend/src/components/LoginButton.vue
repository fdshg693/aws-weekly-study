<script setup>
// BFF版: ログインは /auth/login にリダイレクトするだけ
// PKCE生成、state、nonceは全てBFFサーバーが処理します。
//
// SPA版との違い:
// - SPA版: code_verifier生成 → sessionStorage保存 → Hosted UIリダイレクト
// - BFF版: /auth/login にリダイレクト（BFFが全て処理）
//
// ローカル開発: Viteプロキシが /auth/* を localhost:3000 に転送
// Amplifyデプロイ: getBffUrl() で API Gateway URL を取得

import { getBffUrl } from '../auth/cognito.js'

function handleLogin() {
  // BFFの /auth/login にリダイレクト
  // BFFが以下を処理:
  // 1. code_verifier, code_challenge 生成
  // 2. state 生成（CSRF保護）
  // 3. nonce 生成（リプレイ攻撃防止）
  // 4. Hosted UIの認可URLにリダイレクト
  window.location.href = `${getBffUrl()}/auth/login`
}
</script>

<template>
  <div class="login-section">
    <p>BFFパターンによるCognito認証デモです。</p>
    <button class="btn btn-primary" @click="handleLogin">
      ログイン（Hosted UI）
    </button>
    <div class="flow-description">
      <h3>BFF認証フローの流れ</h3>
      <ol>
        <li>ブラウザ → BFF <code>/auth/login</code> にリダイレクト</li>
        <li>BFFが <code>code_verifier</code>, <code>state</code>, <code>nonce</code> を生成</li>
        <li>BFFが Hosted UI にリダイレクト（<code>code_challenge</code> 付き）</li>
        <li>ログイン後、Cognito → BFF <code>/auth/callback</code> にコールバック</li>
        <li>BFFが認可コード + <code>code_verifier</code> + <code>client_secret</code> でトークン取得</li>
        <li>BFFがIDトークンの署名（JWKS）と <code>nonce</code> を検証</li>
        <li>BFFがセッション作成、<strong>HttpOnly Cookie</strong> でブラウザに返却</li>
        <li>以後、ブラウザはCookie付きで <code>/auth/me</code> を呼ぶだけ</li>
      </ol>
      <div class="security-comparison">
        <h4>SPA版 vs BFF版 セキュリティ比較</h4>
        <table>
          <thead>
            <tr>
              <th></th>
              <th>SPA版</th>
              <th>BFF版</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>トークン保存先</td>
              <td>sessionStorage（JS読み取り可）</td>
              <td>サーバーメモリ（JS読み取り不可）</td>
            </tr>
            <tr>
              <td>XSS耐性</td>
              <td>トークン窃取可能</td>
              <td>トークン窃取不可</td>
            </tr>
            <tr>
              <td>JWT署名検証</td>
              <td>なし</td>
              <td>JWKS検証あり</td>
            </tr>
            <tr>
              <td>state/nonce</td>
              <td>なし</td>
              <td>あり</td>
            </tr>
          </tbody>
        </table>
      </div>
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

.security-comparison {
  margin-top: 1.5rem;
  padding-top: 1rem;
  border-top: 1px solid #dee2e6;
}

.security-comparison h4 {
  margin-top: 0;
  color: #495057;
}

.security-comparison table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
}

.security-comparison th,
.security-comparison td {
  padding: 0.5rem;
  border: 1px solid #dee2e6;
  text-align: left;
}

.security-comparison th {
  background: #e9ecef;
}
</style>
