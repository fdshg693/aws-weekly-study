# Variable Definitions
# ====================
# Cognitoユーザープールの設定に必要な変数を定義します。
# 各変数には適切なバリデーションを設定し、安全性を確保しています。

variable "aws_region" {
  description = "AWSリージョン（例: ap-northeast-1, us-east-1）"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名（dev, staging, prod）。リソース名とタグに使用されます"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod"
  }
}

variable "project_name" {
  description = "プロジェクト名。リソース名のプレフィックスとして使用されます"
  type        = string
  default     = "user-auth"
}

# User Pool Configuration
# -----------------------

variable "user_pool_name" {
  description = "Cognito User Poolの名前。空の場合は自動生成されます"
  type        = string
  default     = ""
}

variable "enable_username_case_sensitivity" {
  description = "ユーザー名の大文字小文字を区別するかどうか（通常はfalseを推奨）"
  type        = bool
  default     = false
}

variable "enable_self_registration" {
  description = "ユーザーが自己登録できるようにするか"
  type        = bool
  default     = true
}

# Password Policy
# ---------------

variable "minimum_password_length" {
  description = "パスワードの最小文字数（8-99）"
  type        = number
  default     = 8
  validation {
    condition     = var.minimum_password_length >= 8 && var.minimum_password_length <= 99
    error_message = "Password length must be between 8 and 99 characters"
  }
}

variable "require_lowercase" {
  description = "パスワードに小文字を必須とするか"
  type        = bool
  default     = true
}

variable "require_uppercase" {
  description = "パスワードに大文字を必須とするか"
  type        = bool
  default     = true
}

variable "require_numbers" {
  description = "パスワードに数字を必須とするか"
  type        = bool
  default     = true
}

variable "require_symbols" {
  description = "パスワードに記号を必須とするか"
  type        = bool
  default     = false
}

variable "temporary_password_validity_days" {
  description = "仮パスワードの有効期間（日数）"
  type        = number
  default     = 7
}

# Email Configuration
# -------------------

variable "email_verification_message" {
  description = "メール検証時に送信されるメッセージ"
  type        = string
  default     = "Your verification code is {####}"
}

variable "email_verification_subject" {
  description = "メール検証の件名"
  type        = string
  default     = "Your verification code"
}

# MFA Configuration
# -----------------

variable "mfa_configuration" {
  description = "MFA設定（OFF, OPTIONAL, ON）"
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, OPTIONAL, or ON"
  }
}

# User Pool Domain
# ----------------

variable "create_user_pool_domain" {
  description = "User Pool Domainを作成するか（Hosted UIを使用する場合に必要）"
  type        = bool
  default     = true
}

variable "domain_prefix" {
  description = "User Pool Domainのプレフィックス。空の場合は自動生成されます"
  type        = string
  default     = ""
}

# Client Configuration
# --------------------

variable "client_name" {
  description = "User Pool Clientの名前。空の場合は自動生成されます"
  type        = string
  default     = ""
}

variable "access_token_validity" {
  description = "アクセストークンの有効期間（時間）"
  type        = number
  default     = 1
}

variable "id_token_validity" {
  description = "IDトークンの有効期間（時間）"
  type        = number
  default     = 1
}

variable "refresh_token_validity" {
  description = "リフレッシュトークンの有効期間（日数）"
  type        = number
  default     = 30
}

variable "prevent_user_existence_errors" {
  description = "ユーザーの存在チェック時のエラーを隠すか（ENABLED推奨）"
  type        = string
  default     = "ENABLED"
  validation {
    condition     = contains(["ENABLED", "LEGACY"], var.prevent_user_existence_errors)
    error_message = "prevent_user_existence_errors must be ENABLED or LEGACY"
  }
}

# OAuth Configuration (Hosted UI)
# --------------------------------

variable "allowed_oauth_flows" {
  description = "許可するOAuthフロー（code, implicit, client_credentials）"
  type        = list(string)
  default     = ["code"]
}

variable "allowed_oauth_scopes" {
  description = "許可するOAuthスコープ"
  type        = list(string)
  default     = ["email", "openid", "profile"]
}

variable "callback_urls" {
  description = "OAuth認証後のコールバックURL"
  type        = list(string)
}

variable "logout_urls" {
  description = "ログアウト後のリダイレクトURL"
  type        = list(string)
}

variable "supported_identity_providers" {
  description = "サポートするIDプロバイダー"
  type        = list(string)
  default     = ["COGNITO"]
}

# Tags
# ----

variable "additional_tags" {
  description = "追加のカスタムタグ"
  type        = map(string)
  default     = {}
}
