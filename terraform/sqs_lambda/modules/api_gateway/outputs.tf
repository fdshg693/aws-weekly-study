#===============================================================================
# API Gateway モジュール - 出力値
#===============================================================================
# 
# このファイルでは API Gateway モジュールの出力値を定義します。
# 他のモジュールや親モジュールから参照するための値を公開します。
#
#===============================================================================

#-------------------------------------------------------------------------------
# REST API の基本情報
#-------------------------------------------------------------------------------

output "api_id" {
  description = <<-EOT
    REST API の ID。
    
    他のリソースから API Gateway を参照する際に使用します。
    例: デプロイメント、ステージ、リソースの作成時
  EOT
  value       = aws_api_gateway_rest_api.this.id
}

output "api_arn" {
  description = <<-EOT
    REST API の ARN。
    
    IAM ポリシーで API Gateway へのアクセス権限を設定する際に使用します。
    
    形式: arn:aws:apigateway:{region}::/restapis/{api-id}
  EOT
  value       = aws_api_gateway_rest_api.this.arn
}

output "api_name" {
  description = <<-EOT
    REST API の名前。
    
    形式: {project_name}-api-{environment}
  EOT
  value       = aws_api_gateway_rest_api.this.name
}

output "api_execution_arn" {
  description = <<-EOT
    REST API の実行 ARN。
    
    Lambda のリソースベースポリシーで、
    API Gateway からの呼び出しを許可する際に使用します。
    
    形式: arn:aws:execute-api:{region}:{account}:{api-id}
    
    使用例:
    source_arn = "{execution_arn}/*/*/*"
  EOT
  value       = aws_api_gateway_rest_api.this.execution_arn
}

#-------------------------------------------------------------------------------
# ステージ情報
#-------------------------------------------------------------------------------

output "stage_name" {
  description = <<-EOT
    デプロイされたステージの名前。
    
    URL の一部として使用されます。
    例: dev, staging, prod
  EOT
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = <<-EOT
    ステージの ARN。
    
    形式: arn:aws:apigateway:{region}::/restapis/{api-id}/stages/{stage-name}
  EOT
  value       = aws_api_gateway_stage.this.arn
}

#-------------------------------------------------------------------------------
# エンドポイント URL
#-------------------------------------------------------------------------------

output "api_endpoint" {
  description = <<-EOT
    REST API のベースエンドポイント URL。
    
    形式: https://{api-id}.execute-api.{region}.amazonaws.com
    
    注意: この URL にはステージ名が含まれていません。
    実際の呼び出しには invoke_url を使用してください。
  EOT
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "invoke_url" {
  description = <<-EOT
    API を呼び出すための完全な URL（ステージ込み）。
    
    形式: https://{api-id}.execute-api.{region}.amazonaws.com/{stage}
    
    使用例:
    curl -X POST {invoke_url}/orders -d '{"item": "laptop"}'
  EOT
  value       = aws_api_gateway_stage.this.invoke_url
}

output "orders_endpoint" {
  description = <<-EOT
    /orders エンドポイントの完全な URL。
    
    形式: https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/orders
    
    使用例:
    curl -X POST {orders_endpoint} \\
      -H "Content-Type: application/json" \\
      -d '{"customer_name": "山田太郎", "items": [{"name": "laptop", "quantity": 1, "price": 98000}], "total_amount": 98000}'
  EOT
  value       = "${aws_api_gateway_stage.this.invoke_url}/orders"
}

#-------------------------------------------------------------------------------
# CloudWatch Logs 情報
#-------------------------------------------------------------------------------

output "access_log_group_name" {
  description = <<-EOT
    アクセスログの CloudWatch Logs グループ名。
    
    ログの確認コマンド:
    aws logs tail {log_group_name} --follow
  EOT
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "access_log_group_arn" {
  description = <<-EOT
    アクセスログの CloudWatch Logs グループ ARN。
  EOT
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

#-------------------------------------------------------------------------------
# デプロイメント情報
#-------------------------------------------------------------------------------

output "deployment_id" {
  description = <<-EOT
    現在のデプロイメント ID。
    
    API の変更をデプロイするたびに新しい ID が生成されます。
  EOT
  value       = aws_api_gateway_deployment.this.id
}

#-------------------------------------------------------------------------------
# 使用例（参考情報）
#-------------------------------------------------------------------------------
# 
# ■ API の呼び出し例（curl）
# 
# # 注文を作成
# curl -X POST "$(terraform output -raw orders_endpoint)" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "customer_name": "山田太郎",
#     "items": [
#       {"name": "laptop", "quantity": 2, "price": 98000}
#     ],
#     "total_amount": 196000
#   }'
#
# ■ ログの確認
#
# # リアルタイムでログを監視
# aws logs tail "$(terraform output -raw access_log_group_name)" --follow
#
# # 最新のログを取得
# aws logs get-log-events \
#   --log-group-name "$(terraform output -raw access_log_group_name)" \
#   --log-stream-name <stream-name>
#
#-------------------------------------------------------------------------------
