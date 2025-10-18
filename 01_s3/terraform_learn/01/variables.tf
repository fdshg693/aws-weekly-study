# Terraform変数定義
#
# 学習ポイント：
# - 変数の型定義とバリデーション
# - デフォルト値の設定
# - 機密情報の扱い方（sensitive）
# - 変数の説明文（description）

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
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "static-website"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "AWS Weekly Study"
    ManagedBy = "Terraform"
    Purpose   = "Learning"
  }
}

# CloudFront設定
variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Invalid price class specified."
  }
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache (seconds)"
  type        = number
  default     = 3600 # 1時間
}

# セキュリティ設定
variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable S3 server-side encryption"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = false # コスト考慮
}

# ライフサイクル設定
variable "log_retention_days" {
  description = "Days to retain access logs before deletion"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3650
    error_message = "Log retention must be between 1 and 3650 days."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to expire noncurrent object versions"
  type        = number
  default     = 30
}

# オプショナル設定（マップ型）
variable "custom_headers" {
  description = "Custom headers for CloudFront response"
  type        = map(string)
  default = {
    "X-Content-Type-Options" = "nosniff"
    "X-Frame-Options"        = "DENY"
    "X-XSS-Protection"       = "1; mode=block"
  }
}

# 複雑な型の例（オブジェクト型）
variable "cors_rules" {
  description = "CORS rules for S3 bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  }))
  default = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
}

# 機密情報（例）
variable "kms_key_arn" {
  description = "KMS key ARN for encryption (if using KMS)"
  type        = string
  default     = ""
  sensitive   = true # Terraform出力で非表示
}

# 変数ファイルの使用例（コメント）
# terraform.tfvars:
# aws_region  = "us-east-1"
# environment = "prod"
# use_custom_domain = true
# domain_name = "example.com"
#
# dev.tfvars:
# environment = "dev"
# enable_logging = false
# cloudfront_price_class = "PriceClass_100"
#
# 使用: terraform apply -var-file="dev.tfvars"
