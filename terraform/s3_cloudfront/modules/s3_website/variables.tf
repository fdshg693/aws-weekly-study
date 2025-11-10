# S3 Website Module Variables

variable "bucket_name" {
  description = "S3バケット名（グローバルで一意である必要がある）"
  type        = string
}

variable "enable_versioning" {
  description = "バージョニングを有効にするかどうか"
  type        = bool
  default     = false
}

variable "block_public_access" {
  description = "パブリックアクセスをブロックするかどうか"
  type        = bool
  default     = true
}

variable "enable_public_access" {
  description = "パブリックアクセスポリシーを適用するかどうか（block_public_access=falseの場合のみ有効）"
  type        = bool
  default     = false
}

variable "cloudfront_oac_arn" {
  description = "CloudFront OACのARN（CloudFront経由でアクセスする場合に指定）"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront DistributionのARN（OAC使用時に必要）"
  type        = string
  default     = ""
}

variable "enable_website_hosting" {
  description = "S3静的ウェブサイトホスティングを有効にするかどうか"
  type        = bool
  default     = true
}

variable "index_document" {
  description = "インデックスドキュメントのファイル名"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "エラードキュメントのファイル名"
  type        = string
  default     = "error.html"
}

variable "website_files" {
  description = "アップロードするウェブサイトファイルのマップ"
  type = map(object({
    key          = string
    source       = string
    content_type = string
  }))
  default = {}
}

variable "tags" {
  description = "リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
