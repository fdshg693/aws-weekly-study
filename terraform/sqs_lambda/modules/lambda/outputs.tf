#===============================================================================
# Lambda モジュール - outputs.tf
#===============================================================================
# このモジュールの出力値を定義
# 他のモジュールやルートモジュールから参照できる
#===============================================================================

#-------------------------------------------------------------------------------
# Lambda 関数の出力
#-------------------------------------------------------------------------------

output "function_name" {
  description = <<-EOT
    Lambda 関数の名前。
    AWS CLI や他のリソースから参照する際に使用。
    
    使用例:
    - aws lambda invoke --function-name <function_name>
    - CloudWatch Logs のフィルタリング
  EOT
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = <<-EOT
    Lambda 関数の ARN（Amazon Resource Name）。
    他の AWS サービスから Lambda を参照する際に使用。
    
    ARN の形式:
    arn:aws:lambda:{region}:{account-id}:function:{function-name}
    
    使用例:
    - SQS のイベントソースマッピングで Lambda をターゲットに指定
    - SNS サブスクリプションで Lambda を指定
    - EventBridge ルールのターゲット指定
  EOT
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = <<-EOT
    Lambda 関数の呼び出し ARN。
    API Gateway から Lambda を呼び出す際に使用する特別な ARN。
    
    ARN の形式:
    arn:aws:apigateway:{region}:lambda:path/2015-03-31/functions/{function-arn}/invocations
    
    使用例:
    - API Gateway の統合設定（aws_api_gateway_integration）
    - HTTP API のルート設定
    
    注意:
    - 通常の function_arn とは形式が異なる
    - API Gateway 連携専用
  EOT
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = <<-EOT
    バージョン修飾子付きの Lambda 関数 ARN。
    特定のバージョンやエイリアスを参照する際に使用。
    
    ARN の形式:
    arn:aws:lambda:{region}:{account-id}:function:{function-name}:{version}
    
    使用例:
    - Lambda エイリアスの設定
    - 特定バージョンへのアクセス制御
  EOT
  value       = aws_lambda_function.this.qualified_arn
}

output "version" {
  description = <<-EOT
    Lambda 関数の最新バージョン番号。
    
    バージョニングについて:
    - Lambda はコード/設定変更時に新しいバージョンを作成できる
    - $LATEST は常に最新のコードを指す
    - 本番環境ではバージョン番号やエイリアスを使用することを推奨
  EOT
  value       = aws_lambda_function.this.version
}

#-------------------------------------------------------------------------------
# IAM ロールの出力
#-------------------------------------------------------------------------------

output "role_arn" {
  description = <<-EOT
    Lambda 関数に関連付けられた IAM ロールの ARN。
    
    使用例:
    - 追加のポリシーをアタッチする場合
    - 他のサービスの信頼ポリシーでこのロールを許可する場合
    - クロスアカウントアクセスの設定
  EOT
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = <<-EOT
    Lambda 関数に関連付けられた IAM ロールの名前。
    
    使用例:
    - aws_iam_role_policy_attachment で追加ポリシーをアタッチ
    - IAM コンソールでの確認
    - AWS CLI でのロール操作
  EOT
  value       = aws_iam_role.lambda.name
}

output "role_id" {
  description = <<-EOT
    Lambda 関数に関連付けられた IAM ロールの一意な ID。
    
    使用例:
    - S3 バケットポリシーでの条件設定
    - リソースベースポリシーでの参照
  EOT
  value       = aws_iam_role.lambda.id
}

#-------------------------------------------------------------------------------
# CloudWatch Logs の出力
#-------------------------------------------------------------------------------

output "log_group_name" {
  description = <<-EOT
    Lambda 関数のログが出力される CloudWatch ロググループの名前。
    
    形式: /aws/lambda/{function-name}
    
    使用例:
    - CloudWatch Logs Insights でのクエリ
    - ログのサブスクリプションフィルター設定
    - メトリクスフィルターの作成
    
    AWS CLI でのログ確認:
    aws logs tail /aws/lambda/{function-name} --follow
  EOT
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = <<-EOT
    CloudWatch ロググループの ARN。
    
    使用例:
    - ログのエクスポート先設定
    - IAM ポリシーでのリソース指定
    - CloudWatch Logs サブスクリプション
  EOT
  value       = aws_cloudwatch_log_group.lambda.arn
}

#-------------------------------------------------------------------------------
# デプロイメント情報
#-------------------------------------------------------------------------------

output "source_code_hash" {
  description = <<-EOT
    デプロイされた Lambda コードの SHA256 ハッシュ値（Base64 エンコード）。
    
    用途:
    - コードの変更検出
    - デプロイのトラッキング
    - CI/CD パイプラインでの検証
    
    このハッシュが変わると、Terraform は Lambda 関数を更新する
  EOT
  value       = aws_lambda_function.this.source_code_hash
}

output "source_code_size" {
  description = <<-EOT
    デプロイされた Lambda コードのサイズ（バイト）。
    
    Lambda のサイズ制限:
    - 直接アップロード: 50MB（ZIP）
    - S3 経由: 250MB（解凍後）
    - コンテナイメージ: 10GB
  EOT
  value       = aws_lambda_function.this.source_code_size
}

output "last_modified" {
  description = <<-EOT
    Lambda 関数が最後に更新された日時（ISO 8601 形式）。
    
    使用例:
    - デプロイ履歴の追跡
    - 監査ログ
  EOT
  value       = aws_lambda_function.this.last_modified
}
