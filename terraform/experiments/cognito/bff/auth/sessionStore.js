// セッションストア ファクトリ
// ==========================
// 環境に応じて適切なストアを選択します。
//
// 切り替え方法:
// - 環境変数 SESSION_STORE_TYPE で制御
//   "memory"   → インメモリMap（ローカル開発用。デフォルト）
//   "dynamodb" → DynamoDB（Lambda環境用）
//
// Lambda環境では以下の環境変数が必要:
// - SESSION_STORE_TYPE=dynamodb
// - SESSION_TABLE_NAME=テーブル名
// - COGNITO_REGION=ap-northeast-1

import { MemoryStore } from './stores/memoryStore.js'
import { DynamoDBStore } from './stores/dynamodbStore.js'

let store = null

/**
 * セッションストアのシングルトンインスタンスを取得
 * @returns {MemoryStore|DynamoDBStore} ストアインスタンス
 */
export function getStore() {
  if (!store) {
    const storeType = process.env.SESSION_STORE_TYPE || 'memory'

    if (storeType === 'dynamodb') {
      const tableName = process.env.SESSION_TABLE_NAME
      const region = process.env.COGNITO_REGION || 'ap-northeast-1'

      if (!tableName) {
        throw new Error('SESSION_TABLE_NAME environment variable is required for DynamoDB store')
      }

      store = new DynamoDBStore({ tableName, region })
      console.log(`[STORE] Using DynamoDB store (table: ${tableName})`)
    } else {
      store = new MemoryStore()
      console.log('[STORE] Using in-memory store (local development)')
    }
  }
  return store
}
