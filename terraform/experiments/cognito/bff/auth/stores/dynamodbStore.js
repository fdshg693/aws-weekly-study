// DynamoDB ストア（Lambda環境用）
// ================================
// セッション・一時データをDynamoDBに保存します。
// TTL（Time To Live）機能により、期限切れデータは自動的に削除されます。
//
// DynamoDB TTLの仕組み:
// - ttl属性にUnixタイムスタンプ（秒）を設定
// - DynamoDBが定期的に期限切れアイテムを自動削除（最大48時間の遅延あり）
// - 削除前でもアプリ側でttlチェックすることで即座に無効化
//
// テーブル構造:
// ┌──────────────┬──────────┬─────────────────────┬─────────┐
// │ pk (S)       │ ttl (N)  │ data (各種属性)     │ ...     │
// ├──────────────┼──────────┼─────────────────────┼─────────┤
// │ session:xxx  │ 17xxxxx  │ tokens, claims等    │         │
// │ pending:yyy  │ 17xxxxx  │ codeVerifier, nonce │         │
// └──────────────┴──────────┴─────────────────────┴─────────┘

import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  UpdateCommand,
  DeleteCommand,
} from '@aws-sdk/lib-dynamodb'

export class DynamoDBStore {
  /**
   * @param {object} options
   * @param {string} options.tableName - DynamoDBテーブル名
   * @param {string} options.region - AWSリージョン
   */
  constructor({ tableName, region }) {
    this.tableName = tableName
    const client = new DynamoDBClient({ region })
    // DynamoDBDocumentClient: JavaScript オブジェクトとDynamoDB型の自動変換
    this.docClient = DynamoDBDocumentClient.from(client)
  }

  /**
   * データを保存
   * @param {string} key - パーティションキー
   * @param {object} value - 保存するデータ
   * @param {number} ttlSeconds - 有効期間（秒）
   */
  async put(key, value, ttlSeconds) {
    const now = Math.floor(Date.now() / 1000)
    await this.docClient.send(new PutCommand({
      TableName: this.tableName,
      Item: {
        pk: key,
        ...value,
        createdAt: Date.now(),
        ttl: ttlSeconds ? now + ttlSeconds : 0,
      },
    }))
  }

  /**
   * データを取得
   * TTL切れのアイテムはDynamoDBの削除遅延があるため、アプリ側でもチェックします。
   *
   * @param {string} key - パーティションキー
   * @returns {object|null} データ（期限切れ・存在しない場合はnull）
   */
  async get(key) {
    const { Item } = await this.docClient.send(new GetCommand({
      TableName: this.tableName,
      Key: { pk: key },
    }))
    if (!Item) return null

    // TTLチェック（DynamoDBの削除は最大48時間遅延するため、アプリ側でも検証）
    if (Item.ttl && Item.ttl < Math.floor(Date.now() / 1000)) {
      return null
    }

    // pkとttlはストアの内部属性なので、返却データから除外
    const { pk, ttl, ...data } = Item
    return data
  }

  /**
   * データを更新（既存データとマージ）
   * DynamoDBのUpdateExpressionを使用して部分更新します。
   *
   * @param {string} key - パーティションキー
   * @param {object} value - 更新データ
   * @returns {boolean} 更新成功したか
   */
  async update(key, value) {
    // まず存在確認
    const existing = await this.get(key)
    if (!existing) return false

    // 全体を上書き（マージ）
    await this.docClient.send(new PutCommand({
      TableName: this.tableName,
      Item: {
        pk: key,
        ...existing,
        ...value,
      },
    }))
    return true
  }

  /**
   * データを削除
   * @param {string} key - パーティションキー
   */
  async delete(key) {
    await this.docClient.send(new DeleteCommand({
      TableName: this.tableName,
      Key: { pk: key },
    }))
  }
}
