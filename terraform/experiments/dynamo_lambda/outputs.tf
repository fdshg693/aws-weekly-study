# =====================================
# API Gateway情報
# =====================================

output "api_endpoint" {
  description = "API GatewayのエンドポイントURL"
  value       = aws_api_gateway_stage.items_api.invoke_url
}

output "api_id" {
  description = "REST APIのID"
  value       = aws_api_gateway_rest_api.items_api.id
}

# =====================================
# DynamoDB情報
# =====================================

output "dynamodb_table_name" {
  description = "DynamoDBテーブル名"
  value       = aws_dynamodb_table.items.name
}

output "dynamodb_table_arn" {
  description = "DynamoDBテーブルのARN"
  value       = aws_dynamodb_table.items.arn
}

# =====================================
# Lambda関数情報
# =====================================

output "lambda_function_name" {
  description = "Lambda関数の名前"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "Lambda関数のARN"
  value       = aws_lambda_function.api.arn
}

# =====================================
# IAMロール情報
# =====================================

output "lambda_role_arn" {
  description = "Lambda関数が使用するIAMロールのARN"
  value       = aws_iam_role.lambda_role.arn
}

# =====================================
# CloudWatch Logs情報
# =====================================

output "log_group_name" {
  description = "Lambda関数のCloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

# =====================================
# テスト用curlコマンド
# =====================================

output "test_commands" {
  description = "APIをテストするためのcurlコマンド"
  value       = <<-EOT
    # ===== アイテム作成 =====
    curl -X POST ${aws_api_gateway_stage.items_api.invoke_url}/items \
      -H "Content-Type: application/json" \
      -d '{"name": "テストアイテム", "description": "テスト用の説明"}'

    # ===== アイテム一覧取得 =====
    curl -X GET ${aws_api_gateway_stage.items_api.invoke_url}/items

    # ===== アイテム個別取得（{id}を実際のIDに置き換え） =====
    curl -X GET ${aws_api_gateway_stage.items_api.invoke_url}/items/{id}

    # ===== アイテム更新（{id}を実際のIDに置き換え） =====
    curl -X PUT ${aws_api_gateway_stage.items_api.invoke_url}/items/{id} \
      -H "Content-Type: application/json" \
      -d '{"name": "更新アイテム", "description": "更新された説明"}'

    # ===== アイテム削除（{id}を実際のIDに置き換え） =====
    curl -X DELETE ${aws_api_gateway_stage.items_api.invoke_url}/items/{id}

    # ===== ログの確認 =====
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
    api_endpoint    = aws_api_gateway_stage.items_api.invoke_url
    stage_name      = var.api_stage_name
    table_name      = aws_dynamodb_table.items.name
    function_name   = aws_lambda_function.api.function_name
    runtime         = aws_lambda_function.api.runtime
    memory_size_mb  = aws_lambda_function.api.memory_size
    timeout_seconds = aws_lambda_function.api.timeout
    environment     = var.environment
    region          = var.aws_region
  }
}
