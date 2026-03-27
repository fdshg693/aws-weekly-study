# outputブロックを使うと、Terraformが作成したリソースの情報（例：IPアドレス、DNSアドレス、リソースID等）を取得して、ユーザーに表示したり、他の用途に使用できます。

# ウェブサイトURL出力
output "website_endpoint" {
  description = "S3 Static Website Endpoint"
  value       = aws_s3_bucket_website_configuration.static_website.website_endpoint
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
  value       = "http://${aws_s3_bucket_website_configuration.static_website.website_endpoint}"
  sensitive   = false 
}
