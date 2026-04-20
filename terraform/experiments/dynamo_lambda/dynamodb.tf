# =====================================
# DynamoDBテーブルの定義
# =====================================

# アイテムを保存するDynamoDBテーブル
# パーティションキーに `id` を使用するシンプルな設計
resource "aws_dynamodb_table" "items" {
  # テーブル名: プロジェクト名と環境名を組み合わせて一意にする
  name = "${var.project_name}-items-${var.environment}"

  # 課金モード
  # PAY_PER_REQUEST: オンデマンド（リクエスト量に応じた課金）
  #   - リクエスト数が少ない開発環境に最適
  #   - キャパシティの事前設定が不要
  #   - 急なトラフィック増加にも自動対応
  # PROVISIONED: プロビジョンド（固定スループットを事前に確保）
  #   - 安定したトラフィックパターンの本番環境向け
  #   - read_capacity / write_capacity の設定が必要
  billing_mode = var.dynamodb_billing_mode

  # パーティションキー（必須）
  # 各アイテムを一意に識別するためのキー
  # DynamoDBはこのキーを基にデータを内部的に分散配置する
  hash_key = "id"

  # パーティションキーの属性定義
  # S = String, N = Number, B = Binary
  attribute {
    name = "id"
    type = "S" # 文字列型（UUID等を想定）
  }

  # ソートキーを追加する場合の例（今回は不使用）
  # range_key = "created_at"
  # attribute {
  #   name = "created_at"
  #   type = "S"
  # }

  # GSI（グローバルセカンダリインデックス）の例（今回は不使用）
  # パーティションキー以外の属性で検索したい場合に使用
  # global_secondary_index {
  #   name            = "name-index"
  #   hash_key        = "name"
  #   projection_type = "ALL"
  # }

  # ポイントインタイムリカバリ（PITR）
  # 有効にすると過去35日間の任意の時点にデータを復元可能
  # 本番環境では有効化を推奨
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }

  # テーブル削除時のデータ保護
  # true にするとテーブルの誤削除を防止できる
  deletion_protection_enabled = var.environment == "production" ? true : false

  # サーバーサイド暗号化
  # デフォルトでAWSマネージドキー（aws/dynamodb）による暗号化が有効
  # KMSカスタマーマネージドキーを使用する場合:
  # server_side_encryption {
  #   enabled     = true
  #   kms_key_arn = aws_kms_key.dynamodb.arn
  # }

  tags = merge(
    {
      Name    = "${var.project_name}-items-${var.environment}"
      Purpose = "CRUD APIのデータストア"
    },
    var.tags
  )
}
