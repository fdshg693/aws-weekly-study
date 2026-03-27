output "state_bucket_name" {
  description = "Terraform remote state を保存する S3 バケット名"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Terraform state lock 用 DynamoDB テーブル名"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "development_backend_config" {
  description = "development 環境向け backend 設定の推奨サンプル（lockfile 主軸）"
  value       = <<-EOT
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "terra_prod/s3/development/terraform.tfstate"
region         = "${var.aws_region}"
encrypt        = true
use_lockfile   = true
# dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}" # 互換運用が必要な場合のみ有効化
EOT
}

output "production_backend_config" {
  description = "production 環境向け backend 設定の推奨サンプル（lockfile 主軸）"
  value       = <<-EOT
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "terra_prod/s3/production/terraform.tfstate"
region         = "${var.aws_region}"
encrypt        = true
use_lockfile   = true
# dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}" # 互換運用が必要な場合のみ有効化
EOT
}
