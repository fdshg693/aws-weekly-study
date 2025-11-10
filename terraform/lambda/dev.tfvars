# =====================================
# 開発環境用の設定
# =====================================

# AWSリージョン
aws_region = "ap-northeast-1" # 東京リージョン

# 環境名
environment = "development"

# Lambda関数名
function_name = "simple-lambda-function"

# ランタイム環境
runtime = "python3.12"

# ハンドラー関数
handler = "lambda_function.lambda_handler"

# リソース設定（開発環境は最小限のリソース）
memory_size = 128  # MB
timeout     = 3    # 秒

# ログ保持期間（開発環境は短め）
log_retention_days = 7 # 7日間

# 環境変数
environment_variables = {
  LOG_LEVEL   = "DEBUG"           # 開発環境では詳細なログを出力
  DEBUG_MODE  = "true"            # デバッグモードを有効化
  API_TIMEOUT = "5"               # API タイムアウト（秒）
}

# VPC設定（開発環境ではVPC外で実行）
enable_vpc             = false
vpc_subnet_ids         = []
vpc_security_group_ids = []

# 同時実行数の制限（開発環境では制限なし）
reserved_concurrent_executions = -1

# DLQ設定（開発環境では無効）
enable_dlq     = false
dlq_target_arn = ""

# トレーシング設定（開発環境では簡易的なトレーシング）
tracing_mode = "PassThrough"

# カスタムタグ
tags = {
  CostCenter = "Development"
  Team       = "Engineering"
  Purpose    = "Testing"
}
