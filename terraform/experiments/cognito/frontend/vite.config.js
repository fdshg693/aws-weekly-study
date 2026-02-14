import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    // BFFへのプロキシ設定
    // /auth/* へのリクエストをBFFサーバー（localhost:3000）に転送します。
    // これにより、フロントエンドとBFFが同一オリジンとして動作し、
    // CookieのSameSite制約を回避できます。
    //
    // 例: fetch('/auth/me') → http://localhost:3000/auth/me に転送
    proxy: {
      '/auth': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
