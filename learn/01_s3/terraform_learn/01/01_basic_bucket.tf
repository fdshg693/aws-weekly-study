# 基本バージョン：シンプルな単一ページサイト用S3バケット
# 
# 学習ポイント：
# - Terraformのリソース定義基礎
# - S3バケットの静的ウェブサイトホスティング設定
# - パブリックアクセス制御とバケットポリシー
# - Terraform変数の活用

# バケット名に使用するローカル変数
locals {
  bucket_name = "static-website-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

# 現在のAWSアカウントID取得
data "aws_caller_identity" "current" {}

# S3バケット作成
resource "aws_s3_bucket" "static_website" {
  bucket = local.bucket_name

  tags = {
    Name        = "Static Website Bucket"
    Environment = "Learning"
    Purpose     = "01_basic_static_hosting"
  }
}

# バージョニング設定（別リソースとして分離）
# Terraform AWS Provider v4以降の推奨方式
resource "aws_s3_bucket_versioning" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 静的ウェブサイトホスティング設定
resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = "index.html"
  }

  # 404エラーページ（オプション）
  # error_document {
  #   key = "error.html"
  # }
}

# パブリックアクセスブロック解除
# 注意：本番環境ではCloudFront OAI経由を推奨
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# バケットポリシー：全員が読み取り可能
resource "aws_s3_bucket_policy" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # depends_onで明示的な依存関係を定義
  # パブリックアクセスブロックを先に解除してからポリシー適用
  depends_on = [aws_s3_bucket_public_access_block.static_website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

# アウトプット：ウェブサイトURL出力
output "website_endpoint" {
  description = "S3 Static Website Endpoint"
  value       = aws_s3_bucket_website_configuration.static_website.website_endpoint
}

output "bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.static_website.id
}

output "website_url" {
  description = "S3 Static Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.static_website.website_endpoint}"
}
