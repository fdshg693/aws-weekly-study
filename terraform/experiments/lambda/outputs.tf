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
    ENVIRONMENT = try(aws_lambda_function.main.environment[0].variables["ENVIRONMENT"], "N/A")
    APP_NAME    = try(aws_lambda_function.main.environment[0].variables["APP_NAME"], "N/A")
    LOG_LEVEL   = try(aws_lambda_function.main.environment[0].variables["LOG_LEVEL"], "N/A")
  }
}

# =====================================
# テスト用のAWS CLIコマンド
# =====================================

output "test_invoke_command" {
  description = "Lambda関数をテストするためのAWS CLIコマンド"
  value       = <<-EOT
    # シンプルなテスト実行
    aws lambda invoke \
      --function-name ${aws_lambda_function.main.function_name} \
      --payload '{"name":"World","message":"Hello"}' \
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

# =====================================
# デプロイサマリー
# =====================================

output "deployment_summary" {
  description = "デプロイメントの概要情報"
  value = {
    function_name   = aws_lambda_function.main.function_name
    runtime         = aws_lambda_function.main.runtime
    memory_size_mb  = aws_lambda_function.main.memory_size
    timeout_seconds = aws_lambda_function.main.timeout
    environment     = var.environment
    region          = var.aws_region
    vpc_enabled     = var.enable_vpc
    tracing_mode    = var.tracing_mode
    log_retention   = var.log_retention_days
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
