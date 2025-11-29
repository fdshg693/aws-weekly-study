#===============================================================================
# DynamoDB モジュール - 出力値定義
#===============================================================================
#
# output ブロックは、モジュールから外部に公開する値を定義します。
#
# ■ output の用途:
#   1. 他のモジュールから参照
#      module.dynamodb.table_arn
#   
#   2. terraform apply 後にコンソールに表示
#   
#   3. terraform output コマンドで取得
#      terraform output table_name
#   
#   4. リモートステートからの参照
#      data.terraform_remote_state.dynamodb.outputs.table_arn
#
# ■ sensitive 属性:
#   - true に設定すると、コンソール出力で値がマスクされる
#   - シークレット、パスワード、API キーなどに使用
#
#===============================================================================

#-------------------------------------------------------------------------------
# テーブル基本情報
#-------------------------------------------------------------------------------

output "table_name" {
  description = <<-EOT
    DynamoDB テーブルの名前。
    
    用途:
    - Lambda 関数からのアクセス時にテーブル名を指定
    - AWS CLI でのデータ操作
    - 環境変数として Lambda に渡す
    
    使用例（Lambda 環境変数設定）:
    environment {
      variables = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
      }
    }
    
    使用例（AWS CLI）:
    aws dynamodb scan --table-name $(terraform output -raw table_name)
  EOT
  value       = aws_dynamodb_table.orders.name
}

output "table_arn" {
  description = <<-EOT
    DynamoDB テーブルの ARN (Amazon Resource Name)。
    
    ARN 形式:
    arn:aws:dynamodb:{region}:{account-id}:table/{table-name}
    
    用途:
    - IAM ポリシーでのリソース指定
    - CloudWatch アラームの設定
    - 他の AWS サービスとの連携設定
    
    使用例（IAM ポリシー）:
    resource "aws_iam_role_policy" "lambda_dynamodb" {
      role = aws_iam_role.lambda.id
      policy = jsonencode({
        Statement = [{
          Effect   = "Allow"
          Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
          Resource = module.dynamodb.table_arn
        }]
      })
    }
    
    注意: GSI へのアクセス権限には、テーブル ARN に加えて
    GSI の ARN も必要です（例: {table_arn}/index/*）
  EOT
  value       = aws_dynamodb_table.orders.arn
}

#-------------------------------------------------------------------------------
# ストリーム情報（Lambda トリガー用）
#-------------------------------------------------------------------------------

output "table_stream_arn" {
  description = <<-EOT
    DynamoDB Streams の ARN。
    
    ARN 形式:
    arn:aws:dynamodb:{region}:{account-id}:table/{table-name}/stream/{timestamp}
    
    用途:
    - Lambda 関数のイベントソースマッピング
    - Kinesis Data Streams への接続
    - クロスリージョンレプリケーション
    
    使用例（Lambda イベントソースマッピング）:
    resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
      event_source_arn  = module.dynamodb.table_stream_arn
      function_name     = aws_lambda_function.processor.arn
      starting_position = "LATEST"
      
      # バッチ設定
      batch_size                         = 100
      maximum_batching_window_in_seconds = 5
      
      # 障害時の動作
      maximum_retry_attempts             = 3
      maximum_record_age_in_seconds      = 3600
    }
    
    注意: 
    - ストリームが無効の場合は null を返します
    - ストリームを有効化するには main.tf で stream_enabled = true に設定
  EOT
  value       = aws_dynamodb_table.orders.stream_arn
}

#-------------------------------------------------------------------------------
# GSI 情報
#-------------------------------------------------------------------------------

output "status_index_name" {
  description = <<-EOT
    ステータス検索用 GSI の名前。
    
    用途:
    - クエリ時に IndexName パラメータで指定
    - アプリケーションコードからの参照
    
    使用例（Python boto3）:
    response = table.query(
        IndexName=os.environ['STATUS_INDEX_NAME'],
        KeyConditionExpression=Key('status').eq('pending')
    )
    
    使用例（Lambda 環境変数設定）:
    environment {
      variables = {
        STATUS_INDEX_NAME = module.dynamodb.status_index_name
      }
    }
  EOT
  value       = "status-index"
}

output "status_index_arn" {
  description = <<-EOT
    ステータス検索用 GSI の ARN。
    
    用途:
    - IAM ポリシーで GSI へのアクセス権限を付与
    
    使用例（IAM ポリシー）:
    resource "aws_iam_role_policy" "lambda_dynamodb" {
      policy = jsonencode({
        Statement = [{
          Effect = "Allow"
          Action = ["dynamodb:Query"]
          Resource = [
            module.dynamodb.table_arn,
            module.dynamodb.status_index_arn
          ]
        }]
      })
    }
  EOT
  value       = "${aws_dynamodb_table.orders.arn}/index/status-index"
}

#-------------------------------------------------------------------------------
# テーブルメタデータ
#-------------------------------------------------------------------------------

output "table_id" {
  description = <<-EOT
    Terraform リソースの ID（テーブル名と同じ）。
    
    用途:
    - Terraform 内部での参照
    - depends_on での依存関係設定
  EOT
  value       = aws_dynamodb_table.orders.id
}

output "hash_key" {
  description = "テーブルのパーティションキー（ハッシュキー）名"
  value       = aws_dynamodb_table.orders.hash_key
}

output "range_key" {
  description = "テーブルのソートキー（レンジキー）名"
  value       = aws_dynamodb_table.orders.range_key
}

#===============================================================================
# 追加の output 例（拡張時に使用）
#===============================================================================
#
# ■ 全インデックスの ARN リスト
#
# output "all_index_arns" {
#   description = "テーブルと全 GSI の ARN リスト（IAM ポリシー用）"
#   value = concat(
#     [aws_dynamodb_table.orders.arn],
#     [for gsi in aws_dynamodb_table.orders.global_secondary_index : 
#      "${aws_dynamodb_table.orders.arn}/index/${gsi.name}"]
#   )
# }
#
# ■ テーブル情報の詳細マップ
#
# output "table_info" {
#   description = "テーブルの詳細情報（デバッグ・ドキュメント用）"
#   value = {
#     name         = aws_dynamodb_table.orders.name
#     arn          = aws_dynamodb_table.orders.arn
#     billing_mode = aws_dynamodb_table.orders.billing_mode
#     hash_key     = aws_dynamodb_table.orders.hash_key
#     range_key    = aws_dynamodb_table.orders.range_key
#     stream_arn   = aws_dynamodb_table.orders.stream_arn
#     gsi_names    = [for gsi in aws_dynamodb_table.orders.global_secondary_index : gsi.name]
#   }
# }
#
#===============================================================================
