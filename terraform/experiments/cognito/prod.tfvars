# Production Environment Configuration
# ====================================
# 本番環境用の変数設定ファイル
# 
# 使用方法:
#   terraform plan -var-file="prod.tfvars"
#   terraform apply -var-file="prod.tfvars"
#
# 注意: 本番環境では、より厳格なセキュリティ設定を使用します。

environment  = "prod"
project_name = "user-auth"

# Region
aws_region = "ap-northeast-1"

# User Pool Settings
enable_self_registration = false  # 本番環境では管理者によるユーザー作成を推奨

# Password Policy (本番環境では厳格な設定)
minimum_password_length = 12
require_lowercase       = true
require_uppercase       = true
require_numbers         = true
require_symbols         = true

# MFA (本番環境では必須を推奨)
mfa_configuration = "ON"

# User Pool Domain
create_user_pool_domain = true

# Token Validity Period (本番環境ではより短い有効期限)
access_token_validity   = 1   # 1 hour
id_token_validity       = 1   # 1 hour
refresh_token_validity  = 7   # 7 days

# Tags
additional_tags = {
  Purpose     = "Production Authentication"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
  Compliance  = "Required"
}
