# Terraform出力定義
#
# 学習ポイント：
# - 出力値の定義と用途
# - sensitive出力の扱い
# - 他モジュールへの値の受け渡し
# - 依存リソースの参照

# S3関連出力
output "s3_bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.static_website.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.static_website.arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.static_website.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.static_website.bucket_regional_domain_name
}

# ログバケット出力
output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = aws_s3_bucket.logs.id
}

# CloudFront関連出力
output "cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.static_website.id
}

output "cloudfront_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.static_website.arn
}

output "cloudfront_status" {
  description = "CloudFront distribution status"
  value       = aws_cloudfront_distribution.static_website.status
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route53 alias"
  value       = aws_cloudfront_distribution.static_website.hosted_zone_id
}

# アクセスURL出力
output "access_urls" {
  description = "All available access URLs"
  value = {
    s3_website   = "http://${aws_s3_bucket_website_configuration.static_website.website_endpoint}"
    cloudfront   = "https://${aws_cloudfront_distribution.static_website.domain_name}"
    custom_domain = var.use_custom_domain ? "https://${var.domain_name}" : "Not configured"
  }
}

# Route53 & ACM出力（条件付き）
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.use_custom_domain ? data.aws_route53_zone.main[0].zone_id : null
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.use_custom_domain ? aws_acm_certificate.cert[0].arn : null
}

# リソース識別情報
output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "ARN of the caller identity"
  value       = data.aws_caller_identity.current.arn
}

# デプロイ情報
output "deployment_info" {
  description = "Deployment summary information"
  value = {
    region            = var.aws_region
    environment       = var.environment
    project_name      = var.project_name
    versioning_enabled = var.enable_versioning
    encryption_enabled = var.enable_encryption
    custom_domain     = var.use_custom_domain ? var.domain_name : "none"
  }
}

# キャッシュ無効化コマンド
output "cache_invalidation_commands" {
  description = "Useful cache invalidation commands"
  value = {
    invalidate_all = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.static_website.id} --paths '/*'"
    invalidate_html = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.static_website.id} --paths '/*.html'"
    check_status = "aws cloudfront list-invalidations --distribution-id ${aws_cloudfront_distribution.static_website.id}"
  }
}

# S3アップロードコマンド例
output "s3_upload_commands" {
  description = "Useful S3 upload commands"
  value = {
    sync_website = "aws s3 sync ./website s3://${aws_s3_bucket.static_website.id}/ --delete"
    upload_file  = "aws s3 cp ./index.html s3://${aws_s3_bucket.static_website.id}/index.html --content-type text/html"
    list_objects = "aws s3 ls s3://${aws_s3_bucket.static_website.id}/"
  }
}

# 機密情報の出力（慎重に扱う）
output "oai_iam_arn" {
  description = "CloudFront Origin Access Identity IAM ARN"
  value       = aws_cloudfront_origin_access_identity.static_website.iam_arn
  sensitive   = true # terraform outputで非表示（-jsonでは表示される）
}

# マップ形式の出力例
output "resource_tags" {
  description = "Tags applied to all resources"
  value       = var.tags
}

# リスト形式の出力例
output "allowed_http_methods" {
  description = "Allowed HTTP methods for CloudFront"
  value       = ["GET", "HEAD", "OPTIONS"]
}

# 出力の使用例（コメント）
# terraform output                          # 全出力を表示
# terraform output cloudfront_url           # 特定の出力を表示
# terraform output -json                    # JSON形式で出力
# terraform output -json > outputs.json     # ファイルに保存
#
# 他モジュールからの参照:
# module.static_website.cloudfront_url
