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

# リソース設定（開発環境でも Bedrock 呼び出しに必要な余裕を持たせる）
memory_size = 256 # MB
timeout     = 15  # 秒

# ログ保持期間（開発環境は短め）
log_retention_days = 7 # 7日間

# 環境変数
environment_variables = {
  LOG_LEVEL   = "DEBUG" # 開発環境では詳細なログを出力
  DEBUG_MODE  = "true"  # デバッグモードを有効化
  API_TIMEOUT = "10"    # API タイムアウト（秒）
}

# Bedrock / API key 設定
bedrock_model_id                       = "amazon.nova-lite-v1:0"
bedrock_max_tokens                     = 256
bedrock_temperature                    = 0.5
authorizer_cache_ttl_seconds           = 0
api_key_rotation_days                  = 30
api_key_secret_recovery_window_in_days = 7
api_key_length                         = 48

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
