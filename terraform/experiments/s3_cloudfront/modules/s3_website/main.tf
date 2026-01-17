# S3バケット本体とバージョニング設定

resource "aws_s3_bucket" "static_website" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name    = "Static Website Bucket"
      Purpose = "static_website_hosting"
    }
  )
}

# バージョニング設定
resource "aws_s3_bucket_versioning" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# パブリックアクセスブロック設定
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# バケットポリシー：CloudFront OAC経由またはパブリックアクセス
# 注意: CloudFront使用時は、CloudFront作成後にこのポリシーが適用されます
resource "aws_s3_bucket_policy" "static_website" {
  # ポリシーを適用する条件：
  # 1. CloudFront使用時（cloudfront_distribution_arn != ""）
  # 2. パブリックアクセス許可時（enable_public_access == true）
  count  = var.cloudfront_distribution_arn != "" || var.enable_public_access ? 1 : 0
  bucket = aws_s3_bucket.static_website.id

  depends_on = [aws_s3_bucket_public_access_block.static_website]

  # cloudfront_distribution_arnがある->CloudFront OAC経由のアクセス許可
  # それ以外でenable_public_accessがtrue->全員に読み取り許可
  policy = var.cloudfront_distribution_arn != "" ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
    }) : jsonencode({
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

# 静的ウェブサイトホスティング設定
resource "aws_s3_bucket_website_configuration" "static_website" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# S3バケットへのファイルアップロード
resource "aws_s3_object" "website_files" {
  for_each = var.website_files

  bucket       = aws_s3_bucket.static_website.id
  key          = each.value.key
  source       = each.value.source
  content_type = each.value.content_type
  etag         = filemd5(each.value.source)
}
