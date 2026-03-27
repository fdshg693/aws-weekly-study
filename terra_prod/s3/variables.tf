# ==============================
# 変数の定義・型などを設定するインターフェース部分
# - AWSリージョンの指定
# - 環境（本番/開発）の指定
# ==============================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1" # 東京リージョン

  # 代入される値の妥当性チェック
  validation {
    # 以下の形式であることを担保
    # {a~zが2文字}-{a~zが1文字以上}-{0~9が1文字}
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    # 表示するエラーメッセージ
    error_message = "Region must be valid AWS region format (e.g., ap-northeast-1)."
  }
}

# 本番か開発環境かを区別するための変数
variable "environment" {
  description = "本番環境か開発環境かを指定します。本番：production、開発：その他"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be one of: development, production."
  }
}

variable "access_log_retention_days" {
  description = "アクセスログを保持する日数"
  type        = number
  default     = 180

  validation {
    condition     = var.access_log_retention_days >= 30
    error_message = "access_log_retention_days must be 30 or greater."
  }
}

variable "access_log_transition_to_standard_ia_days" {
  description = "アクセスログをSTANDARD_IAへ移行するまでの日数"
  type        = number
  default     = 30

  validation {
    condition     = var.access_log_transition_to_standard_ia_days > 0 && var.access_log_transition_to_standard_ia_days < var.access_log_retention_days
    error_message = "access_log_transition_to_standard_ia_days must be greater than 0 and less than access_log_retention_days."
  }
}

variable "access_log_abort_incomplete_multipart_days" {
  description = "未完了マルチパートアップロードを中断するまでの日数"
  type        = number
  default     = 7

  validation {
    condition     = var.access_log_abort_incomplete_multipart_days > 0
    error_message = "access_log_abort_incomplete_multipart_days must be greater than 0."
  }
}