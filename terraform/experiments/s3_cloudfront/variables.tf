# ==============================
# - aws_region/environment: デプロイ環境の指定
# - enable_cloudfront/cloudfront_price_class: CloudFront設定
# - custom_domain_names/acm_certificate_arn: カスタムドメインと証明書設定
# ==============================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1" # 東京リージョン

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Region must be valid AWS region format (e.g., ap-northeast-1)."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "enable_cloudfront" {
  description = "CloudFrontを有効にするかどうか（無効時はS3単体でのホスティング）"
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "CloudFrontの価格クラス"
  type        = string
  # PriceClass_All: すべてのエッジロケーション（最高性能、最高コスト）世界中のすべてのリージョン
  # PriceClass_200: 南米以外のすべてのエッジロケーション 北米、ヨーロッパ、アジア、中東、アフリカ
  # PriceClass_100: 北米、ヨーロッパ、イスラエルのみ（最低コスト）最も安価だが、アジアからのアクセスは遅くなる可能性がある
  default     = "PriceClass_200" 
}

# CloudFrontディストリビューションにアクセスするためのカスタムドメイン。これを設定しないとデフォルトの d111111abcdef8.cloudfront.net のようなURLになります。
variable "custom_domain_names" {
  description = "カスタムドメイン名のリスト（CloudFront使用時）"
  type        = list(string)
  default     = []
}

# ACM (AWS Certificate Manager) で発行したSSL/TLS証明書の一意の識別子です。
# CloudFront用の証明書は必ず us-east-1 リージョンで作成する必要があります
# ARN形式: arn:aws:acm:リージョン:アカウントID:certificate/証明書ID
# カスタムドメイン（aliases）を使う場合は必須 証明書のドメインはaliasesに指定したドメインと一致する必要があります
variable "acm_certificate_arn" {
  description = "ACM証明書のARN（カスタムドメイン使用時、us-east-1リージョンで作成）"
  type        = string
  default     = ""
}
