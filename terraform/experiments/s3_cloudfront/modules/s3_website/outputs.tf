# S3 Website Module Outputs

output "bucket_id" {
  description = "S3バケットID"
  value       = aws_s3_bucket.static_website.id
}

output "bucket_arn" {
  description = "S3バケットARN"
  value       = aws_s3_bucket.static_website.arn
}

output "bucket_domain_name" {
  description = "S3バケットのドメイン名"
  value       = aws_s3_bucket.static_website.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3バケットのリージョナルドメイン名"
  value       = aws_s3_bucket.static_website.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "S3静的ウェブサイトエンドポイント"
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.static_website[0].website_endpoint : null
}

output "website_domain" {
  description = "S3静的ウェブサイトドメイン"
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.static_website[0].website_domain : null
}
