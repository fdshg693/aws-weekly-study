# AWS Cognito User Pool Configuration
# ====================================
# Cognitoユーザープール、クライアント、ドメインを作成します。
#
# リソース構成:
# 1. User Pool - ユーザーベースの認証基盤
# 2. User Pool Client - API認証用クライアント
# 3. User Pool Domain - Hosted UI用ドメイン（オプション）
#
# 参考:
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool
# - https://docs.aws.amazon.com/cognito/latest/developerguide/

# ========================================
# User Pool
# ========================================
# ユーザープールはユーザーのディレクトリです。
# ユーザー属性、パスワードポリシー、MFA設定などを定義します。
#
# 重要なオプション:
# - username_attributes: ユーザー名として使用する属性（email, phone_number, または両方）
# - auto_verified_attributes: 自動検証する属性（email推奨）
# - mfa_configuration: MFAの設定（OFF, OPTIONAL, ON）
# - account_recovery_setting: アカウント復旧方法

resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name != "" ? var.user_pool_name : "${var.project_name}-${var.environment}"

  # Username Configuration
  # ---------------------
  # ユーザー名の設定。emailをユーザー名として使用することで、
  # ユーザーフレンドリーなログインが可能になります。
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Case Sensitivity
  # ----------------
  # ユーザー名の大文字小文字の区別。
  # falseにすることで、user@example.com と USER@example.com を同一視します。
  username_configuration {
    case_sensitive = var.enable_username_case_sensitivity
  }

  # Password Policy
  # ---------------
  # パスワードの複雑性要件を定義します。
  # セキュリティと使いやすさのバランスを考慮して設定してください。
  password_policy {
    minimum_length                   = var.minimum_password_length
    require_lowercase                = var.require_lowercase
    require_uppercase                = var.require_uppercase
    require_numbers                  = var.require_numbers
    require_symbols                  = var.require_symbols
    temporary_password_validity_days = var.temporary_password_validity_days
  }

  # User Attributes
  # ---------------
  # ユーザープールで必須とする属性と、カスタム属性を定義します。
  # email以外に、名前、電話番号、生年月日などを追加できます。
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Email Configuration
  # -------------------
  # メール検証のメッセージをカスタマイズします。
  # SESを使用する場合は、email_configuration blockで設定します。
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_CODE"
    email_subject         = var.email_verification_subject
    email_message         = var.email_verification_message
    email_subject_by_link = "${var.project_name} - Verify your email"
    email_message_by_link = "Please click the link below to verify your email address. {##Verify Email##}"
  }

  # MFA Configuration
  # -----------------
  # 多要素認証の設定です。
  # - OFF: MFA無効
  # - OPTIONAL: ユーザーが選択可能
  # - ON: 全ユーザーに必須
  mfa_configuration = var.mfa_configuration

  # Software Token MFA (TOTP) Configuration
  # ---------------------------------------
  # OPTIONALまたはONの場合、少なくとも1つのMFA方式を有効にする必要があります。
  # ソフトウェアトークン（TOTP）は、Google AuthenticatorやAuthyなどのアプリで使用できます。
  software_token_mfa_configuration {
    enabled = var.mfa_configuration != "OFF"
  }

  # Account Recovery
  # ----------------
  # パスワードリセット時の復旧方法を定義します。
  # 複数の方法を設定することで、ユーザーの利便性が向上します。
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Admin Create User Configuration
  # --------------------------------
  # 管理者によるユーザー作成の動作を定義します。
  # allow_admin_create_user_onlyをfalseにすることで、
  # ユーザー自己登録が可能になります。
  admin_create_user_config {
    allow_admin_create_user_only = !var.enable_self_registration
  }

  # Device Configuration
  # --------------------
  # デバイス記憶機能の設定。
  # ユーザーのデバイスを記憶することで、MFAをスキップできます。
  #
  # 注意: デバイス追跡を有効にすると、REFRESH_TOKEN_AUTHフローで
  # SRPベースのデバイス確認（ConfirmDevice）が必要になります。
  # CLIやbashスクリプトからのテストにはSRPライブラリが必要なため、
  # SDK（Amplify, boto3等）を使用しない場合は無効にしてください。
  #
  # device_configuration {
  #   challenge_required_on_new_device      = true
  #   device_only_remembered_on_user_prompt = true
  # }

  # Deletion Protection
  # -------------------
  # 環境によって削除保護を設定します。
  # 本番環境ではACTIVE、開発環境ではINACTIVEが推奨です。
  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-user-pool"
    },
    var.additional_tags
  )
}

# ========================================
# User Pool Client
# ========================================
# アプリケーションがUser Poolと通信するためのクライアント設定です。
# 認証フローやトークンの有効期限などを定義します。
#
# 重要なフロー:
# - USER_PASSWORD_AUTH: ユーザー名/パスワード認証（サーバーサイド向け）
# - USER_SRP_AUTH: SRP（Secure Remote Password）認証（クライアント向け）
# - REFRESH_TOKEN_AUTH: トークンリフレッシュ

resource "aws_cognito_user_pool_client" "main" {
  name         = var.client_name != "" ? var.client_name : "${var.project_name}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Token Validity
  # --------------
  # トークンの有効期限を設定します。
  # セキュリティとユーザビリティのバランスを考慮してください。
  access_token_validity  = var.access_token_validity
  id_token_validity      = var.id_token_validity
  refresh_token_validity = var.refresh_token_validity

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Authentication Flows
  # --------------------
  # 有効にする認証フローを選択します。
  # - ALLOW_USER_PASSWORD_AUTH: 直接的なユーザー名/パスワード認証
  # - ALLOW_USER_SRP_AUTH: より安全なSRP認証
  # - ALLOW_REFRESH_TOKEN_AUTH: トークンリフレッシュ
  # - ALLOW_CUSTOM_AUTH: カスタム認証チャレンジ
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Client Secret
  # -------------
  # クライアントシークレットを生成しません。
  # サーバーサイドアプリケーションで必要な場合は、
  # generate_secret = true に設定してください。
  generate_secret = false

  # Token Revocation
  # ----------------
  # トークン失効機能を有効にします。
  # これにより、ログアウト時にリフレッシュトークンを明示的に失効させることができます。
  enable_token_revocation = true

  # Security
  # --------
  # ユーザーの存在チェック時のエラーメッセージを標準化します。
  # これにより、ユーザーの存在を推測する攻撃を防ぎます。
  prevent_user_existence_errors = var.prevent_user_existence_errors

  # Read/Write Attributes
  # ---------------------
  # クライアントがアクセスできる属性を制限します。
  # セキュリティのため、必要最小限の属性のみを許可してください。
  read_attributes  = ["email", "email_verified", "name"]
  write_attributes = ["email", "name"]

  # OAuth Configuration
  # -------------------
  # Hosted UIやOAuthフローを使用する場合に設定します。
  # create_user_pool_domain = true の場合に自動的に有効化されます。
  allowed_oauth_flows                  = var.create_user_pool_domain ? var.allowed_oauth_flows : []
  allowed_oauth_flows_user_pool_client = var.create_user_pool_domain
  allowed_oauth_scopes                 = var.create_user_pool_domain ? var.allowed_oauth_scopes : []
  callback_urls                        = var.create_user_pool_domain ? var.callback_urls : null
  logout_urls                          = var.create_user_pool_domain ? var.logout_urls : null
  supported_identity_providers         = var.create_user_pool_domain ? var.supported_identity_providers : null
}

# ========================================
# User Pool Domain
# ========================================
# Hosted UI（Cognitoが提供するログインページ）を使用するための
# カスタムドメインまたはCognitoドメインを作成します。
#
# ドメインの種類:
# - Cognito Domain: <prefix>.auth.<region>.amazoncognito.com
# - Custom Domain: 独自ドメイン（ACM証明書が必要）
#
# 注意: Cognito Domainのprefixはグローバルで一意である必要があります。

resource "aws_cognito_user_pool_domain" "main" {
  count = var.create_user_pool_domain ? 1 : 0

  # ドメインプレフィックスを生成
  # 空の場合は、プロジェクト名と環境から自動生成します。
  # グローバルで一意である必要があるため、ランダム性を持たせることを推奨します。
  domain       = var.domain_prefix != "" ? var.domain_prefix : "${var.project_name}-${var.environment}-${substr(aws_cognito_user_pool.main.id, 0, 8)}"
  user_pool_id = aws_cognito_user_pool.main.id

  # カスタムドメインを使用する場合は以下を設定:
  # certificate_arn = aws_acm_certificate.cert.arn
}
