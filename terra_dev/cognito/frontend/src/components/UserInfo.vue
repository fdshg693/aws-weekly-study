<script setup>
defineProps({
  claims: {
    type: Object,
    required: true,
  },
})
</script>

<template>
  <div class="user-info">
    <h2>ユーザー情報</h2>
    <table>
      <tbody>
        <tr>
          <th>Email</th>
          <td>{{ claims.email }}</td>
        </tr>
        <tr v-if="claims.name">
          <th>Name</th>
          <td>{{ claims.name }}</td>
        </tr>
        <tr>
          <th>Subject (sub)</th>
          <td><code>{{ claims.sub }}</code></td>
        </tr>
        <tr>
          <th>Issuer</th>
          <td><code>{{ claims.iss }}</code></td>
        </tr>
        <tr>
          <th>認証時刻</th>
          <td>{{ new Date(claims.auth_time * 1000).toLocaleString('ja-JP') }}</td>
        </tr>
        <tr>
          <th>トークン発行</th>
          <td>{{ new Date(claims.iat * 1000).toLocaleString('ja-JP') }}</td>
        </tr>
        <tr>
          <th>トークン期限</th>
          <td>{{ new Date(claims.exp * 1000).toLocaleString('ja-JP') }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.user-info {
  margin-bottom: 1.5rem;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 0.6rem 1rem;
  text-align: left;
  border-bottom: 1px solid #dee2e6;
}

th {
  width: 160px;
  color: #495057;
  font-weight: 600;
}

code {
  background: #e9ecef;
  padding: 0.15rem 0.4rem;
  border-radius: 3px;
  font-size: 0.85em;
  word-break: break-all;
}
</style>
