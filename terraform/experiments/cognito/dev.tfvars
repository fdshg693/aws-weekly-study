# Development Environment Configuration
# =====================================
# 開発環境用の変数設定ファイル
# 
# 使用方法:
#   terraform plan -var-file="dev.tfvars"
#   terraform apply -var-file="dev.tfvars"

environment  = "dev"
project_name = "user-auth"

# Region
aws_region = "ap-northeast-1"

# User Pool Settings
enable_self_registration = true

# Password Policy (開発環境では緩めの設定)
minimum_password_length = 8
require_lowercase       = true
require_uppercase       = true
require_numbers         = true
require_symbols         = false

# MFA (開発環境ではオプショナル)
mfa_configuration = "OPTIONAL"

# User Pool Domain (Hosted UIテスト用)
create_user_pool_domain = true

# Callback/Logout URLs
# ローカル開発用にlocalhost:5173を追加
# Amplify URLは初回デプロイ後に追加してください
callback_urls = ["http://localhost:5173/callback", "https://claude.ai/new"]
logout_urls   = ["http://localhost:5173/", "https://claude.ai/new"]

# Token Validity Period
access_token_validity   = 1  # 1 hour
id_token_validity       = 1  # 1 hour
refresh_token_validity  = 30 # 30 days

# Tags
additional_tags = {
  Purpose = "Development and Testing"
  Owner   = "Development Team"
}
