// インメモリストア（ローカル開発用）
// ==================================
// Mapベースのセッション・一時データ保存。
// サーバー再起動で全データが消えるため、開発・テスト専用です。

export class MemoryStore {
  constructor() {
    this.data = new Map()
  }

  /**
   * データを保存
   * @param {string} key - キー
   * @param {object} value - 保存するデータ
   * @param {number} ttlSeconds - 有効期間（秒）。期限後に自動削除
   */
  async put(key, value, ttlSeconds) {
    this.data.set(key, {
      ...value,
      createdAt: Date.now(),
    })
    // TTL後に自動削除（メモリリーク防止）
    if (ttlSeconds) {
      setTimeout(() => this.data.delete(key), ttlSeconds * 1000)
    }
  }

  /**
   * データを取得
   * @param {string} key - キー
   * @returns {object|null} データ（存在しない場合はnull）
   */
  async get(key) {
    return this.data.get(key) || null
  }

  /**
   * データを更新（既存データとマージ）
   * @param {string} key - キー
   * @param {object} value - 更新データ
   * @returns {boolean} 更新成功したか
   */
  async update(key, value) {
    const existing = this.data.get(key)
    if (!existing) return false
    this.data.set(key, { ...existing, ...value })
    return true
  }

  /**
   * データを削除
   * @param {string} key - キー
   */
  async delete(key) {
    this.data.delete(key)
  }
}
