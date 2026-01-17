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
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
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