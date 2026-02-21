# =====================================
# 本番環境用の設定
# =====================================

# AWSリージョン
aws_region = "ap-northeast-1" # 東京リージョン

# 環境名
environment = "production"

# プロジェクト名
project_name = "dynamo-lambda-api"

# Lambda関数名
function_name = "items-api"

# ランタイム環境
runtime = "python3.12"

# ハンドラー関数
handler = "lambda_function.lambda_handler"

# リソース設定（本番環境はパフォーマンスと信頼性を重視）
memory_size = 256 # MB（開発環境より高い値を設定）
timeout     = 29  # 秒（API Gatewayのタイムアウトに合わせる）

# DynamoDB課金モード（本番環境もオンデマンドで開始し、必要に応じてPROVISIONEDに変更）
dynamodb_billing_mode = "PAY_PER_REQUEST"

# API Gatewayステージ名
api_stage_name = "prod"

# ログ保持期間（本番環境は長期保存）
log_retention_days = 90 # 90日間

# カスタムタグ
tags = {
  CostCenter  = "Production"
  Team        = "Platform"
  Purpose     = "Business"
  Criticality = "High"
}
