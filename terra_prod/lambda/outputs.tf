# =====================================
# Lambda関数の基本情報
# =====================================

output "function_name" {
  description = "Lambda関数の名前"
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "Lambda関数のARN（Amazon Resource Name）"
  value       = aws_lambda_function.main.arn
}

output "function_invoke_arn" {
  description = "Lambda関数の呼び出しARN（API Gateway等から使用）"
  value       = aws_lambda_function.main.invoke_arn
}

output "api_gateway_name" {
  description = "HTTP API Gatewayの名前"
  value       = aws_apigatewayv2_api.lambda_http_api.name
}

output "api_gateway_id" {
  description = "HTTP API GatewayのID"
  value       = aws_apigatewayv2_api.lambda_http_api.id
}

output "api_gateway_stage_name" {
  description = "HTTP API Gatewayのステージ名"
  value       = aws_apigatewayv2_stage.default.name
}

output "api_invoke_url" {
  description = "API Gateway経由でLambdaを呼び出すURL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "authorizer_function_name" {
  description = "API Gateway の x-api-key 検証を行う Lambda Authorizer 関数名"
  value       = aws_lambda_function.authorizer.function_name
}

output "rotation_function_name" {
  description = "Secrets Manager の API キー自動ローテーション Lambda 関数名"
  value       = aws_lambda_function.rotation.function_name
}

output "function_version" {
  description = "Lambda関数の現在のバージョン"
  value       = aws_lambda_function.main.version
}

output "function_qualified_arn" {
  description = "バージョン番号を含むLambda関数のARN"
  value       = aws_lambda_function.main.qualified_arn
}

# =====================================
# Lambda関数の設定情報
# =====================================

output "function_runtime" {
  description = "Lambda関数のランタイム環境"
  value       = aws_lambda_function.main.runtime
}

output "function_handler" {
  description = "Lambda関数のハンドラー"
  value       = aws_lambda_function.main.handler
}

output "function_memory_size" {
  description = "Lambda関数に割り当てられたメモリサイズ（MB）"
  value       = aws_lambda_function.main.memory_size
}

output "function_timeout" {
  description = "Lambda関数のタイムアウト時間（秒）"
  value       = aws_lambda_function.main.timeout
}

output "function_source_code_hash" {
  description = "デプロイされたコードのハッシュ値（変更検知に使用）"
  value       = aws_lambda_function.main.source_code_hash
  sensitive   = false
}

# =====================================
# IAMロール情報
# =====================================

output "lambda_role_name" {
  description = "Lambda関数が使用するIAMロールの名前"
  value       = aws_iam_role.lambda_role.name
}

output "lambda_role_arn" {
  description = "Lambda関数が使用するIAMロールのARN"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_id" {
  description = "Lambda関数が使用するIAMロールのID"
  value       = aws_iam_role.lambda_role.id
}

output "authorizer_role_name" {
  description = "Authorizer Lambda が使用する IAM ロール名"
  value       = aws_iam_role.authorizer_role.name
}

output "rotation_role_name" {
  description = "Rotation Lambda が使用する IAM ロール名"
  value       = aws_iam_role.rotation_role.name
}

# =====================================
# CloudWatch Logs情報
# =====================================

output "log_group_name" {
  description = "Lambda関数のCloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "log_group_arn" {
  description = "Lambda関数のCloudWatch LogsグループのARN"
  value       = aws_cloudwatch_log_group.lambda_log_group.arn
}

output "log_retention_days" {
  description = "ログの保持期間（日数）"
  value       = aws_cloudwatch_log_group.lambda_log_group.retention_in_days
}

# =====================================
# CloudWatch Logsの直接リンク
# =====================================

output "cloudwatch_logs_url" {
  description = "Lambda関数のCloudWatch Logsコンソールへの直接リンク"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.lambda_log_group.name, "/", "$252F")}"
}

# =====================================
# Lambda関数のコンソールURL
# =====================================

output "lambda_console_url" {
  description = "Lambda関数のAWSコンソールへの直接リンク"
  value       = "https://console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${aws_lambda_function.main.function_name}"
}

# =====================================
# デプロイ情報
# =====================================

output "last_modified" {
  description = "Lambda関数の最終更新日時"
  value       = aws_lambda_function.main.last_modified
}

output "code_size" {
  description = "デプロイされたコードのサイズ（バイト）"
  value       = aws_lambda_function.main.source_code_size
}

# =====================================
# 環境変数（機密情報を除く）
# =====================================

output "environment_variables" {
  description = "Lambda関数に設定された環境変数（機密情報は除外）"
  value = {
    ENVIRONMENT      = try(aws_lambda_function.main.environment[0].variables["ENVIRONMENT"], "N/A")
    APP_NAME         = try(aws_lambda_function.main.environment[0].variables["APP_NAME"], "N/A")
    LOG_LEVEL        = try(aws_lambda_function.main.environment[0].variables["LOG_LEVEL"], "N/A")
    BEDROCK_MODEL_ID = try(aws_lambda_function.main.environment[0].variables["BEDROCK_MODEL_ID"], "N/A")
  }
}

output "api_key_secret_name" {
  description = "API キーを保存する Secrets Manager シークレット名"
  value       = aws_secretsmanager_secret.api_key.name
}

output "api_key_secret_arn" {
  description = "API キーを保存する Secrets Manager シークレット ARN"
  value       = aws_secretsmanager_secret.api_key.arn
}

# =====================================
# テスト用のAWS CLIコマンド
# =====================================

output "test_invoke_command" {
  description = "Lambda関数をテストするためのAWS CLIコマンド"
  value       = <<-EOT
    # Bedrock 呼び出しを直接 Lambda invoke でテスト
    aws lambda invoke \
      --function-name ${aws_lambda_function.main.function_name} \
      --payload '{"prompt":"AWS Lambda を一文で説明してください"}' \
      --region ${var.aws_region} \
      response.json
    
    # レスポンスの確認
    cat response.json | jq .
  EOT
}

output "get_logs_command" {
  description = "Lambda関数のログを取得するAWS CLIコマンド"
  value       = <<-EOT
    # 最新のログストリームを取得
    aws logs tail ${aws_cloudwatch_log_group.lambda_log_group.name} \
      --follow \
      --region ${var.aws_region}
  EOT
}

output "test_api_command" {
  description = "API Gateway経由でLambda関数をテストするcurlコマンド"
  value       = <<-EOT
    # まず API キーを取得
    API_KEY=$(aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.api_key.name} \
      --region ${var.aws_region} \
      --query SecretString \
      --output text | jq -r '.api_key // .')

    # 認証済み GET ヘルスチェック
    curl -sS \
      -H "x-api-key: $$API_KEY" \
      ${aws_apigatewayv2_stage.default.invoke_url} | jq .

    # 認証済み POST で Bedrock を呼び出す
    curl -sS \
      -X POST \
      -H 'Content-Type: application/json' \
      -H "x-api-key: $$API_KEY" \
      -d '{"prompt":"AWS Lambda を一文で説明してください"}' \
      ${aws_apigatewayv2_stage.default.invoke_url} | jq .
  EOT
}

output "get_api_key_command" {
  description = "Secrets Manager から API キーを取得する AWS CLI コマンド"
  value       = <<-EOT
    aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.api_key.name} \
      --region ${var.aws_region} \
      --query SecretString \
      --output text | jq -r '.api_key // .'
  EOT
}

output "rotate_api_key_command" {
  description = "API キーを即時ローテーションする AWS CLI コマンド"
  value       = <<-EOT
    aws secretsmanager rotate-secret \
      --secret-id ${aws_secretsmanager_secret.api_key.name} \
      --region ${var.aws_region} \
      --rotate-immediately
  EOT
}

# =====================================
# デプロイサマリー
# =====================================

output "deployment_summary" {
  description = "デプロイメントの概要情報"
  value = {
    function_name         = aws_lambda_function.main.function_name
    api_invoke_url        = aws_apigatewayv2_stage.default.invoke_url
    runtime               = aws_lambda_function.main.runtime
    memory_size_mb        = aws_lambda_function.main.memory_size
    timeout_seconds       = aws_lambda_function.main.timeout
    environment           = var.environment
    region                = var.aws_region
    vpc_enabled           = var.enable_vpc
    tracing_mode          = var.tracing_mode
    log_retention         = var.log_retention_days
    bedrock_model_id      = var.bedrock_model_id
    api_key_secret_name   = aws_secretsmanager_secret.api_key.name
    api_key_rotation_days = var.api_key_rotation_days
    authorizer_function   = aws_lambda_function.authorizer.function_name
    rotation_function     = aws_lambda_function.rotation.function_name
  }
}

# =====================================
# VPC設定情報（VPC有効時のみ）
# =====================================

output "vpc_config" {
  description = "Lambda関数のVPC設定情報"
  value = var.enable_vpc ? {
    subnet_ids         = aws_lambda_function.main.vpc_config[0].subnet_ids
    security_group_ids = aws_lambda_function.main.vpc_config[0].security_group_ids
    vpc_id             = aws_lambda_function.main.vpc_config[0].vpc_id
  } : null
}

# =====================================
# 参考情報
# =====================================

# Outputの使い方:
# terraform output                    # すべての出力値を表示
# terraform output function_name      # 特定の出力値を表示
# terraform output -json              # JSON形式で出力
# terraform output -raw function_arn  # RAW形式で出力（パイプ処理に便利）

# 他のTerraformモジュールでの参照例:
# module.lambda.function_name
# module.lambda.function_arn
