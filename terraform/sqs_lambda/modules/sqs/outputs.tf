#===============================================================================
# SQS モジュール - 出力定義
#===============================================================================
#
# 【出力値の用途】
# これらの出力値は、他のモジュールやリソースから参照されます：
# - Lambda のイベントソースマッピングで queue_arn を使用
# - アプリケーションの環境変数に queue_url を設定
# - IAM ポリシーで queue_arn を参照
# - CloudWatch アラームで queue_name を使用
#
#===============================================================================

#-------------------------------------------------------------------------------
# メインキューの出力
#-------------------------------------------------------------------------------

output "queue_url" {
  description = <<-EOT
    メインキューの URL
    
    メッセージの送受信に使用する URL です。
    アプリケーションコードや Lambda の環境変数で使用します。
    
    例: https://sqs.ap-northeast-1.amazonaws.com/123456789012/myapp-orders-queue-dev
    
    使用例（Python boto3）:
    sqs.send_message(QueueUrl=queue_url, MessageBody='...')
    sqs.receive_message(QueueUrl=queue_url)
  EOT
  value       = aws_sqs_queue.main_queue.url
}

output "queue_arn" {
  description = <<-EOT
    メインキューの ARN（Amazon Resource Name）
    
    IAM ポリシーや Lambda イベントソースマッピングで使用します。
    
    例: arn:aws:sqs:ap-northeast-1:123456789012:myapp-orders-queue-dev
    
    使用例（IAM ポリシー）:
    {
      "Effect": "Allow",
      "Action": ["sqs:ReceiveMessage", "sqs:DeleteMessage"],
      "Resource": "arn:aws:sqs:..."
    }
    
    使用例（Lambda イベントソースマッピング）:
    event_source_arn = module.sqs.queue_arn
  EOT
  value       = aws_sqs_queue.main_queue.arn
}

output "queue_name" {
  description = <<-EOT
    メインキューの名前
    
    CloudWatch メトリクスやアラームで使用します。
    AWS コンソールでの識別にも使用されます。
    
    例: myapp-orders-queue-dev
    
    CloudWatch メトリクスのディメンション:
    - QueueName: myapp-orders-queue-dev
  EOT
  value       = aws_sqs_queue.main_queue.name
}

#-------------------------------------------------------------------------------
# Dead Letter Queue の出力
#-------------------------------------------------------------------------------

output "dlq_url" {
  description = <<-EOT
    Dead Letter Queue の URL
    
    失敗したメッセージを調査・再処理する際に使用します。
    運用ツールやスクリプトで DLQ からメッセージを取得する際に使用します。
    
    例: https://sqs.ap-northeast-1.amazonaws.com/123456789012/myapp-orders-dlq-dev
    
    DLQ メッセージの再処理例:
    1. DLQ からメッセージを受信
    2. 問題を修正
    3. メインキューに再送信
    4. DLQ からメッセージを削除
  EOT
  value       = aws_sqs_queue.dead_letter_queue.url
}

output "dlq_arn" {
  description = <<-EOT
    Dead Letter Queue の ARN
    
    IAM ポリシーで DLQ へのアクセス権限を設定する際に使用します。
    CloudWatch アラームのターゲット指定にも使用されます。
    
    例: arn:aws:sqs:ap-northeast-1:123456789012:myapp-orders-dlq-dev
    
    監視のポイント:
    - ApproximateNumberOfMessagesVisible > 0 でアラート
    - DLQ にメッセージが入ったら即座に対応が必要
  EOT
  value       = aws_sqs_queue.dead_letter_queue.arn
}

output "dlq_name" {
  description = <<-EOT
    Dead Letter Queue の名前
    
    CloudWatch メトリクスやダッシュボードで使用します。
    
    例: myapp-orders-dlq-dev
    
    推奨アラーム設定:
    - メトリクス: ApproximateNumberOfMessagesVisible
    - 条件: > 0
    - 期間: 1分
    - アクション: SNS 通知
  EOT
  value       = aws_sqs_queue.dead_letter_queue.name
}

#-------------------------------------------------------------------------------
# 追加の便利な出力
#-------------------------------------------------------------------------------

output "queue_id" {
  description = <<-EOT
    メインキューの ID
    
    Terraform 内部で使用される一意識別子です。
    通常は URL と同じ値ですが、依存関係の管理に使用されます。
  EOT
  value       = aws_sqs_queue.main_queue.id
}

output "dlq_id" {
  description = <<-EOT
    Dead Letter Queue の ID
    
    Terraform 内部で使用される一意識別子です。
  EOT
  value       = aws_sqs_queue.dead_letter_queue.id
}
