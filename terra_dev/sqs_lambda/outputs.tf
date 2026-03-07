#===============================================================================
# outputs.tf - ルートモジュールの出力定義
#===============================================================================
#
# このファイルでは、Terraform apply 後に表示される出力値を定義します。
# 出力値は以下の用途で使用されます:
#
# 1. terraform apply 後のコンソール表示
# 2. terraform output コマンドでの取得
# 3. 他の Terraform 設定からの参照（リモートステート経由）
# 4. CI/CD パイプラインでの環境変数設定
#
# ■ 出力値の分類
#   - API Gateway 関連: API エンドポイント URL
#   - Lambda 関連: 関数名と ARN
#   - SQS 関連: キュー URL
#   - DynamoDB 関連: テーブル名と ARN
#   - テスト用: 動作確認コマンド
#
#===============================================================================

#-------------------------------------------------------------------------------
# API Gateway 関連の出力
#-------------------------------------------------------------------------------

output "api_endpoint" {
  description = <<-EOT
    API Gateway のベースエンドポイント URL（ステージ込み）
    
    形式: https://{api-id}.execute-api.{region}.amazonaws.com/{stage}
    
    この URL に各リソースパスを追加して API を呼び出します。
    例: {api_endpoint}/orders
  EOT
  value       = module.api_gateway.invoke_url
}

output "orders_endpoint" {
  description = <<-EOT
    /orders エンドポイントの完全な URL
    
    注文を作成するための POST リクエスト先です。
    
    使用例:
    curl -X POST {orders_endpoint} \
      -H "Content-Type: application/json" \
      -d '{"customer_name": "山田太郎", "items": [{"name": "laptop", "quantity": 1, "price": 98000}], "total_amount": 98000}'
  EOT
  value       = module.api_gateway.orders_endpoint
}

#-------------------------------------------------------------------------------
# Lambda 関連の出力
#-------------------------------------------------------------------------------

output "producer_function_name" {
  description = <<-EOT
    Producer Lambda 関数の名前
    
    AWS CLI での呼び出し例:
    aws lambda invoke \
      --function-name {producer_function_name} \
      --payload '{"body": "{\"customer_name\": \"テスト顧客\", \"items\": [{\"name\": \"laptop\", \"quantity\": 1, \"price\": 98000}], \"total_amount\": 98000}"}' \
      response.json
    
    ログの確認:
    aws logs tail /aws/lambda/{producer_function_name} --follow
  EOT
  value       = module.lambda_producer.function_name
}

output "producer_function_arn" {
  description = <<-EOT
    Producer Lambda 関数の ARN
    
    他の AWS サービスから参照する際に使用します。
    形式: arn:aws:lambda:{region}:{account}:function:{name}
  EOT
  value       = module.lambda_producer.function_arn
}

output "consumer_function_name" {
  description = <<-EOT
    Consumer Lambda 関数の名前
    
    ログの確認:
    aws logs tail /aws/lambda/{consumer_function_name} --follow
    
    手動でのテスト呼び出し（SQS メッセージ形式）:
    aws lambda invoke \
      --function-name {consumer_function_name} \
      --payload file://test_event.json \
      response.json
  EOT
  value       = module.lambda_consumer.function_name
}

output "consumer_function_arn" {
  description = <<-EOT
    Consumer Lambda 関数の ARN
    
    イベントソースマッピングで参照されます。
  EOT
  value       = module.lambda_consumer.function_arn
}

#-------------------------------------------------------------------------------
# SQS 関連の出力
#-------------------------------------------------------------------------------

output "queue_url" {
  description = <<-EOT
    メイン SQS キューの URL
    
    メッセージの送受信に使用する URL です。
    Producer Lambda がこの URL にメッセージを送信します。
    
    AWS CLI でのメッセージ送信例:
    aws sqs send-message \
      --queue-url {queue_url} \
      --message-body '{"customer_name": "テスト顧客", "items": [{"name": "laptop", "quantity": 1, "price": 98000}], "total_amount": 98000}'
    
    キューの状態確認:
    aws sqs get-queue-attributes \
      --queue-url {queue_url} \
      --attribute-names ApproximateNumberOfMessages
  EOT
  value       = module.sqs.queue_url
}

output "queue_arn" {
  description = <<-EOT
    メイン SQS キューの ARN
    
    IAM ポリシーやイベントソースマッピングで参照されます。
  EOT
  value       = module.sqs.queue_arn
}

output "dlq_url" {
  description = <<-EOT
    Dead Letter Queue (DLQ) の URL
    
    処理に失敗したメッセージが移動されるキューです。
    運用時に定期的に監視が必要です。
    
    DLQ 内のメッセージ確認:
    aws sqs receive-message \
      --queue-url {dlq_url} \
      --max-number-of-messages 10
    
    DLQ からメインキューへの再送信:
    aws sqs start-message-move-task \
      --source-arn {dlq_arn} \
      --destination-arn {queue_arn}
  EOT
  value       = module.sqs.dlq_url
}

output "dlq_arn" {
  description = <<-EOT
    Dead Letter Queue (DLQ) の ARN
    
    アラートの設定などに使用します。
  EOT
  value       = module.sqs.dlq_arn
}

#-------------------------------------------------------------------------------
# DynamoDB 関連の出力
#-------------------------------------------------------------------------------

output "dynamodb_table_name" {
  description = <<-EOT
    DynamoDB テーブルの名前
    
    Consumer Lambda がこのテーブルにデータを書き込みます。
    
    テーブル内のデータ確認:
    aws dynamodb scan --table-name {dynamodb_table_name}
    
    特定のアイテムを取得:
    aws dynamodb get-item \
      --table-name {dynamodb_table_name} \
      --key '{"order_id": {"S": "order-001"}}'
  EOT
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = <<-EOT
    DynamoDB テーブルの ARN
    
    IAM ポリシーでのリソース指定に使用します。
    形式: arn:aws:dynamodb:{region}:{account}:table/{name}
  EOT
  value       = module.dynamodb.table_arn
}

#-------------------------------------------------------------------------------
# アカウント情報
#-------------------------------------------------------------------------------

output "aws_account_id" {
  description = <<-EOT
    AWS アカウント ID
    
    デプロイ先のアカウントを確認するために出力します。
    本番環境への誤デプロイを防ぐ確認用途としても有用です。
  EOT
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = <<-EOT
    デプロイ先の AWS リージョン
    
    リソースがデプロイされているリージョンを確認できます。
  EOT
  # 注: name 属性は非推奨のため、id を使用
  value       = data.aws_region.current.id
}

#===============================================================================
# テスト用コマンド（使い方の説明）
#===============================================================================
#
# 以下のコマンドで動作確認ができます。
#
# ■ 1. API 経由で注文を作成
#
#   # エンドポイント URL を取得
#   ORDERS_ENDPOINT=$(terraform output -raw orders_endpoint)
#
#   # 注文を送信
#   curl -X POST "$ORDERS_ENDPOINT" \
#     -H "Content-Type: application/json" \
#     -d '{
#       "customer_name": "山田太郎",
#       "items": [
#         {"name": "ノートパソコン", "quantity": 2, "price": 98000}
#       ],
#       "total_amount": 196000
#     }'
#
# ■ 2. SQS キューの状態確認
#
#   QUEUE_URL=$(terraform output -raw queue_url)
#   aws sqs get-queue-attributes \
#     --queue-url "$QUEUE_URL" \
#     --attribute-names All
#
# ■ 3. DynamoDB のデータ確認
#
#   TABLE_NAME=$(terraform output -raw dynamodb_table_name)
#   aws dynamodb scan --table-name "$TABLE_NAME"
#
# ■ 4. Lambda ログの確認
#
#   # Producer Lambda のログ
#   PRODUCER_NAME=$(terraform output -raw producer_function_name)
#   aws logs tail "/aws/lambda/$PRODUCER_NAME" --follow
#
#   # Consumer Lambda のログ
#   CONSUMER_NAME=$(terraform output -raw consumer_function_name)
#   aws logs tail "/aws/lambda/$CONSUMER_NAME" --follow
#
# ■ 5. Dead Letter Queue の確認
#
#   DLQ_URL=$(terraform output -raw dlq_url)
#   aws sqs get-queue-attributes \
#     --queue-url "$DLQ_URL" \
#     --attribute-names ApproximateNumberOfMessages
#
# ■ 6. エンドツーエンドテスト
#
#   # 複数の注文を連続送信
#   for i in {1..5}; do
#     curl -X POST "$ORDERS_ENDPOINT" \
#       -H "Content-Type: application/json" \
#       -d "{\"customer_name\": \"顧客$i\", \"items\": [{\"name\": \"product-$i\", \"quantity\": 1, \"price\": 1000}], \"total_amount\": 1000}"
#     sleep 1
#   done
#
#   # 処理結果を確認
#   aws dynamodb scan --table-name "$TABLE_NAME" | jq '.Items | length'
#
#===============================================================================

#-------------------------------------------------------------------------------
# 便利なテスト用出力
#-------------------------------------------------------------------------------

output "test_curl_command" {
  description = <<-EOT
    テスト用の curl コマンド
    
    コピー＆ペーストで API をテストできます。
    シェルで直接実行してください。
  EOT
  value       = <<-EOT
    curl -X POST "${module.api_gateway.orders_endpoint}" \
      -H "Content-Type: application/json" \
      -d '{
        "customer_name": "山田太郎",
        "items": [
          {"name": "ノートパソコン", "quantity": 1, "price": 98000},
          {"name": "マウス", "quantity": 2, "price": 3500}
        ],
        "total_amount": 105000
      }'
  EOT
}

output "test_commands" {
  description = <<-EOT
    各種テストコマンドのまとめ
    
    terraform output test_commands で表示し、
    必要なコマンドをコピーして実行してください。
  EOT
  value       = <<-EOT
    
    =====================================================
    📋 テストコマンド集
    =====================================================
    
    1️⃣ API で注文を作成:
    curl -X POST "${module.api_gateway.orders_endpoint}" \
      -H "Content-Type: application/json" \
      -d '{
        "customer_name": "テスト顧客",
        "items": [{"name": "laptop", "quantity": 1, "price": 120000}],
        "total_amount": 120000
      }'
    
    2️⃣ SQS キューの状態確認:
    aws sqs get-queue-attributes \
      --queue-url "${module.sqs.queue_url}" \
      --attribute-names ApproximateNumberOfMessages
    
    3️⃣ DynamoDB のデータ確認:
    aws dynamodb scan --table-name "${module.dynamodb.table_name}"
    
    4️⃣ Producer Lambda のログ確認:
    aws logs tail "/aws/lambda/${module.lambda_producer.function_name}" --follow
    
    5️⃣ Consumer Lambda のログ確認:
    aws logs tail "/aws/lambda/${module.lambda_consumer.function_name}" --follow
    
    6️⃣ Dead Letter Queue の確認:
    aws sqs get-queue-attributes \
      --queue-url "${module.sqs.dlq_url}" \
      --attribute-names ApproximateNumberOfMessages
    
    =====================================================
  EOT
}
