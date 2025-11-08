# Route53 DNS設定とACM証明書
#
# 学習ポイント：
# - Route53ホストゾーンとDNSレコード管理
# - ACM証明書の発行と検証（DNS検証）
# - CloudFrontとカスタムドメインの統合
# - count / for_each による条件付きリソース作成

# 変数：カスタムドメイン使用フラグ
variable "use_custom_domain" {
  description = "Whether to use custom domain with Route53"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Custom domain name (e.g., example.com)"
  type        = string
  default     = ""
}

# Route53ホストゾーン取得（既存のゾーンを使用）
data "aws_route53_zone" "main" {
  count = var.use_custom_domain ? 1 : 0
  name  = var.domain_name
}

# ACM証明書（us-east-1リージョン必須：CloudFront用）
resource "aws_acm_certificate" "cert" {
  count = var.use_custom_domain ? 1 : 0

  # CloudFrontで使用する場合はus-east-1が必須
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"] # ワイルドカード
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "Static Website Certificate"
    Environment = "Learning"
  }
}

# ACM証明書DNS検証レコード
resource "aws_route53_record" "cert_validation" {
  for_each = var.use_custom_domain ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# 証明書検証完了待機
resource "aws_acm_certificate_validation" "cert" {
  count = var.use_custom_domain ? 1 : 0

  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 Aレコード：CloudFrontディストリビューションへのエイリアス
resource "aws_route53_record" "website" {
  count = var.use_custom_domain ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAAレコード：IPv6対応
resource "aws_route53_record" "website_ipv6" {
  count = var.use_custom_domain ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# wwwサブドメイン用レコード（オプション）
resource "aws_route53_record" "website_www" {
  count = var.use_custom_domain ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# 出力
output "certificate_arn" {
  description = "ACM Certificate ARN"
  value       = var.use_custom_domain ? aws_acm_certificate.cert[0].arn : null
}

output "website_domain" {
  description = "Website Custom Domain"
  value       = var.use_custom_domain ? "https://${var.domain_name}" : null
}
