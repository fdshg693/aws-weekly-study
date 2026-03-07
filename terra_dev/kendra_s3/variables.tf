# 変数の定義（環境ごとに dev.tfvars / prod.tfvars で値を切り替える想定）

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"

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

# Kendra Index
variable "kendra_index_name" {
  description = "Kendra index name"
  type        = string
}

variable "kendra_index_description" {
  description = "Kendra index description"
  type        = string
  default     = "Kendra index managed by Terraform"
}

variable "kendra_edition" {
  description = "Kendra edition: DEVELOPER_EDITION or ENTERPRISE_EDITION"
  type        = string
  default     = "DEVELOPER_EDITION"

  validation {
    condition     = contains(["DEVELOPER_EDITION", "ENTERPRISE_EDITION"], var.kendra_edition)
    error_message = "kendra_edition must be one of: DEVELOPER_EDITION, ENTERPRISE_EDITION."
  }
}

# Kendra Data Source (S3)
variable "data_source_name" {
  description = "Kendra data source name"
  type        = string
  default     = "s3"
}

variable "data_source_language_code" {
  description = <<EOT
Language code for the Kendra Data Source.

用途:
- この Data Source が取り込むドキュメントの主言語を Kendra に伝えるための設定です。
- Kendra の言語処理（トークナイズ/正規化など）に影響し、検索精度に関係します。

代表的な値（AWSの言語コード）:
- ja, en, ko, zh, es, fr, de, it, pt, ar, hi

null の場合:
- Terraform では引数を未設定扱いにし、Kendra 側のデフォルト挙動に従います。
EOT
  type        = string
  default     = null

  validation {
    condition = (
      var.data_source_language_code == null ||
      contains([
        "ar",
        "de",
        "en",
        "es",
        "fr",
        "hi",
        "it",
        "ja",
        "ko",
        "pt",
        "zh",
      ], var.data_source_language_code)
    )
    error_message = "data_source_language_code must be null or one of: ar, de, en, es, fr, hi, it, ja, ko, pt, zh."
  }
}

variable "schedule" {
  description = "Kendra data source sync schedule (EventBridge cron expression). Set null to disable scheduled sync."
  type        = string
  default     = null
}

# S3 (Kendra S3 Data Source 用)
# - TODO#3 で Kendra の Data Source を S3 に切り替える際に利用します。
# - TODO#2 ではバケットを作成するだけ（Kendra 側の設定はまだ変更しない）。

variable "s3_bucket_name" {
  description = <<EOT
S3 bucket name used as the data source for Amazon Kendra (S3 connector).

注意:
- S3 バケット名は全 AWS / 全リージョンでグローバルにユニークである必要があります。
- デフォルトは要件により "kendra-s3" ですが、既に使われている場合は override してください。
EOT
  type        = string
  default     = "kendra-s3"
}

variable "s3_inclusion_prefix" {
  description = <<EOT
Inclusion prefix (key prefix) under the bucket for documents ingested by Kendra.

例:
- "documents/" の場合: s3://<bucket>/documents/ 配下のみを対象にする想定

注意:
- 末尾は "/" を推奨（このプロジェクトの出力 `s3_uri` もその前提で組み立てます）
EOT
  type        = string
  default     = "documents/"

  validation {
    condition     = !startswith(var.s3_inclusion_prefix, "/") && endswith(var.s3_inclusion_prefix, "/")
    error_message = "s3_inclusion_prefix must not start with '/' and must end with '/' (e.g., 'documents/')."
  }
}
