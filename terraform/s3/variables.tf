# 変数の定義・型などを設定するインターフェース部分
# 実際の値の指定は、コマンドラインオプションや環境変数、tfvarsファイルなどで行う想定

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  # ここではあくまでデフォルト値のみの設定にとどめて、実際の指定は基本的にコマンドラインや環境変数・tfvarsファイルで行う想定
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
  description = "Deployment environment (e.g., development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}