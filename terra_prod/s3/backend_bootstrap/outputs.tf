output "state_bucket_name" {
  description = "Terraform remote state を保存する S3 バケット名"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Terraform state lock 用 DynamoDB テーブル名"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "development_backend_config" {
  description = "development 環境向け backend 設定のサンプル"
  value       = <<-EOT
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "terra_prod/s3/development/terraform.tfstate"
region         = "${var.aws_region}"
encrypt        = true
use_lockfile   = true
dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
EOT
}

output "production_backend_config" {
  description = "production 環境向け backend 設定のサンプル"
  value       = <<-EOT
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "terra_prod/s3/production/terraform.tfstate"
region         = "${var.aws_region}"
encrypt        = true
use_lockfile   = true
dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
EOT
}
