# =====================================
# 開発環境用の設定
# =====================================

# AWSリージョン
aws_region = "ap-northeast-1" # 東京リージョン

# 環境名
environment = "development"

# プロジェクト名
project_name = "dynamo-lambda-api"

# Lambda関数名
function_name = "items-api"

# ランタイム環境
runtime = "python3.12"

# ハンドラー関数
handler = "lambda_function.lambda_handler"

# リソース設定（開発環境は最小限のリソース）
memory_size = 128 # MB
timeout     = 10  # 秒

# DynamoDB課金モード（開発環境はオンデマンド）
dynamodb_billing_mode = "PAY_PER_REQUEST"

# API Gatewayステージ名
api_stage_name = "dev"

# ログ保持期間（開発環境は短め）
log_retention_days = 7 # 7日間

# カスタムタグ
tags = {
  CostCenter = "Development"
  Team       = "Engineering"
  Purpose    = "Learning"
}
