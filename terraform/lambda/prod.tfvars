# =====================================
# 本番環境用の設定
# =====================================

# AWSリージョン
aws_region = "ap-northeast-1" # 東京リージョン

# 環境名
environment = "production"

# Lambda関数名
function_name = "simple-lambda-function"

# ランタイム環境
runtime = "python3.12"

# ハンドラー関数
handler = "lambda_function.lambda_handler"

# リソース設定（本番環境はパフォーマンスと信頼性を重視）
memory_size = 512  # MB（開発環境より高い値を設定）
timeout     = 30   # 秒（余裕を持ったタイムアウト）

# ログ保持期間（本番環境は長期保存）
log_retention_days = 90 # 90日間（コンプライアンス要件に応じて調整）

# 環境変数
environment_variables = {
  LOG_LEVEL   = "INFO"            # 本番環境では必要な情報のみログ出力
  DEBUG_MODE  = "false"           # デバッグモードを無効化
  API_TIMEOUT = "10"              # API タイムアウト（秒）
}

# VPC設定（本番環境でプライベートリソースにアクセスする場合）
# 以下は例です。実際の環境に合わせて変更してください
enable_vpc = false
# enable_vpc             = true
# vpc_subnet_ids         = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"] # プライベートサブネット
# vpc_security_group_ids = ["sg-xxxxxxxxx"]                         # Lambda用セキュリティグループ

# 同時実行数の制限（本番環境ではコスト管理のため制限を設定）
# -1 = 制限なし
# 0 = 関数を無効化
# 1以上 = 指定された数まで同時実行を制限
reserved_concurrent_executions = 100 # 最大100まで同時実行

# DLQ設定（本番環境では有効化を推奨）
# 失敗したイベントを確実にキャッチするため
enable_dlq = false
# enable_dlq     = true
# dlq_target_arn = "arn:aws:sqs:ap-northeast-1:123456789012:lambda-dlq" # SQSキューのARN

# トレーシング設定（本番環境では詳細なトレーシングを有効化）
tracing_mode = "Active" # X-Rayによる詳細なトレーシング

# カスタムタグ
tags = {
  CostCenter  = "Production"
  Team        = "Platform"
  Purpose     = "Business"
  Criticality = "High"
  Compliance  = "Required"
}
