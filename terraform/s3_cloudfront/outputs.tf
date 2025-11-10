# Root Module Outputs

# ===========================
# S3関連の出力
# ===========================
output "s3_bucket_id" {
  description = "S3バケットID"
  value       = module.s3_website.bucket_id
}

output "s3_bucket_arn" {
  description = "S3バケットARN"
  value       = module.s3_website.bucket_arn
}

output "s3_website_endpoint" {
  description = "S3静的ウェブサイトエンドポイント（CloudFront無効時）"
  value       = module.s3_website.website_endpoint
}

output "s3_website_url" {
  description = "S3静的ウェブサイトURL（CloudFront無効時）"
  # website_endpointがnullでない場合にのみURLを返す
  value       = module.s3_website.website_endpoint != null ? "http://${module.s3_website.website_endpoint}" : null
}

# ===========================
# CloudFront関連の出力
# ===========================

# count や for_each で条件付けされたリソース/モジュール → [0] などのインデックスが必要
# CloudFrontは変数次第で、有効/無効が切り替わるため

output "cloudfront_distribution_id" {
  description = "CloudFront DistributionのID"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_id : null
}

output "cloudfront_distribution_arn" {
  description = "CloudFront DistributionのARN"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_arn : null
}

output "cloudfront_domain_name" {
  description = "CloudFrontのドメイン名"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_domain_name : null
}

output "cloudfront_url" {
  description = "CloudFrontのURL"
  value       = var.enable_cloudfront ? "https://${module.cloudfront[0].distribution_domain_name}" : null
}

# アクセス用URL（CloudFrontが有効な場合はそちらを、無効な場合はS3を表示）
output "website_url" {
  description = "ウェブサイトのアクセスURL"
  value       = var.enable_cloudfront ? "https://${module.cloudfront[0].distribution_domain_name}" : (module.s3_website.website_endpoint != null ? "http://${module.s3_website.website_endpoint}" : null)
}
