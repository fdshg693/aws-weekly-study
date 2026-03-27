# outputブロックを使うと、Terraformが作成したリソースの情報（例：IPアドレス、DNSアドレス、リソースID等）を取得して、ユーザーに表示したり、他の用途に使用できます。

# ウェブサイトURL出力
output "website_endpoint" {
  description = "S3 Static Website Endpoint"
  value       = local.current_env.website_enabled ? aws_s3_bucket_website_configuration.static_website[0].website_endpoint : null
  sensitive   = false
}

# バケット名出力
output "bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.static_website.id
  sensitive   = false
}

# ウェブサイトURL出力（http://付き）
output "website_url" {
  description = "S3 Static Website URL"
  value       = local.current_env.website_enabled ? "http://${aws_s3_bucket_website_configuration.static_website[0].website_endpoint}" : null
  sensitive   = false
}

output "access_log_bucket_name" {
  description = "S3 access log bucket name"
  value       = aws_s3_bucket.access_logs.id
  sensitive   = false
}

output "s3_access_log_prefix" {
  description = "S3 server access log prefix"
  value       = local.s3_access_log_prefix
  sensitive   = false
}

output "cloudfront_access_log_prefix" {
  description = "Reserved CloudFront access log prefix for future integration"
  value       = local.cloudfront_access_log_prefix
  sensitive   = false
}

output "delivery_mode" {
  description = "Current delivery mode for the selected environment"
  value       = local.current_env.delivery_mode
  sensitive   = false
}
