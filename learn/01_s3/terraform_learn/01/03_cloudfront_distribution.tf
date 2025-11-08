# CloudFront CDN統合
#
# 学習ポイント：
# - CloudFrontディストリビューション設定
# - Origin Access Identity (OAI) によるS3アクセス制御
# - キャッシュビヘイビアとTTL設定
# - カスタムエラーレスポンス

# CloudFront Origin Access Identity 作成
# S3バケットへの直接アクセスを防ぎ、CloudFront経由のみ許可
resource "aws_cloudfront_origin_access_identity" "static_website" {
  comment = "OAI for static website bucket"
}

# S3バケットポリシー：CloudFront OAIのみアクセス許可
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontReadOnly"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.static_website.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

# CloudFrontディストリビューション
resource "aws_cloudfront_distribution" "static_website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Static Website Distribution"
  price_class         = "PriceClass_100" # 北米・欧州のみ（コスト削減）

  # S3 Originの設定
  origin {
    domain_name = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_website.id}"

    # OAI設定
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static_website.cloudfront_access_identity_path
    }
  }

  # デフォルトキャッシュビヘイビア
  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.static_website.id}"
    viewer_protocol_policy = "redirect-to-https" # HTTP→HTTPS自動リダイレクト

    # 許可するHTTPメソッド
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # キャッシュポリシー（マネージドポリシー使用）
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    # 圧縮を有効化
    compress = true
  }

  # 特定パスのキャッシュビヘイビア（例：静的アセット）
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = "S3-${aws_s3_bucket.static_website.id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    # 長いTTL設定（静的アセット用）
    min_ttl     = 0
    default_ttl = 86400  # 1日
    max_ttl     = 31536000 # 1年

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    compress = true
  }

  # カスタムエラーレスポンス（SPA対応）
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  # 地理的制限（オプション）
  restrictions {
    geo_restriction {
      restriction_type = "none"
      # 特定国のみ許可する場合
      # restriction_type = "whitelist"
      # locations        = ["US", "JP", "GB"]
    }
  }

  # SSL/TLS証明書設定
  viewer_certificate {
    cloudfront_default_certificate = true
    # カスタムドメイン使用時はACM証明書を指定
    # acm_certificate_arn      = aws_acm_certificate.cert.arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "Static Website Distribution"
    Environment = "Learning"
  }
}

# CloudFrontマネージドキャッシュポリシー取得
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# 出力
output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.static_website.domain_name
}

output "cloudfront_url" {
  description = "CloudFront Distribution URL"
  value       = "https://${aws_cloudfront_distribution.static_website.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.static_website.id
}
