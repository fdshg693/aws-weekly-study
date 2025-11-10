# CloudFront Module Variables

variable "distribution_name" {
  description = "CloudFront Distributionの名前"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3バケットのリージョナルドメイン名"
  type        = string
}

variable "origin_id" {
  description = "CloudFrontオリジンのID"
  type        = string
  default     = "S3Origin"
}

variable "enabled" {
  description = "CloudFront Distributionを有効にするかどうか"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "IPv6を有効にするかどうか"
  type        = bool
  default     = true
}

variable "comment" {
  description = "CloudFront Distributionのコメント"
  type        = string
  default     = ""
}

variable "default_root_object" {
  description = "デフォルトのルートオブジェクト"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFrontの価格クラス"
  type        = string
  default     = "PriceClass_200" # 日本・アジア・北米・ヨーロッパ
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_classは PriceClass_All, PriceClass_200, PriceClass_100 のいずれかである必要があります。"
  }
}

variable "aliases" {
  description = "カスタムドメイン名（CNAMEエイリアス）"
  type        = list(string)
  default     = []
}

variable "allowed_methods" {
  description = "許可するHTTPメソッド"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "cached_methods" {
  description = "キャッシュするHTTPメソッド"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "viewer_protocol_policy" {
  description = "ビューワープロトコルポリシー"
  type        = string
  default     = "redirect-to-https"
  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policyは allow-all, https-only, redirect-to-https のいずれかである必要があります。"
  }
}

variable "compress" {
  description = "自動圧縮を有効にするかどうか"
  type        = bool
  default     = true
}

variable "cache_policy_id" {
  description = "カスタムキャッシュポリシーID（指定しない場合はCachingOptimizedを使用）"
  type        = string
  default     = ""
}

variable "origin_request_policy_id" {
  description = "オリジンリクエストポリシーID"
  type        = string
  default     = null
}

variable "custom_error_responses" {
  description = "カスタムエラーレスポンス設定"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/error.html"
      error_caching_min_ttl = 10
    }
  ]
}

variable "geo_restriction_type" {
  description = "地理的制限のタイプ（none, whitelist, blacklist）"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "geo_restriction_typeは none, whitelist, blacklist のいずれかである必要があります。"
  }
}

variable "geo_restriction_locations" {
  description = "地理的制限を適用する国コードのリスト"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM証明書のARN（カスタムドメイン使用時）"
  type        = string
  default     = ""
}

variable "minimum_protocol_version" {
  description = "最小TLSプロトコルバージョン"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "logging_bucket" {
  description = "ログ保存先のS3バケット（例: mybucket.s3.amazonaws.com）"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "ログファイルのプレフィックス"
  type        = string
  default     = "cloudfront/"
}

variable "logging_include_cookies" {
  description = "ログにCookieを含めるかどうか"
  type        = bool
  default     = false
}

variable "tags" {
  description = "リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
