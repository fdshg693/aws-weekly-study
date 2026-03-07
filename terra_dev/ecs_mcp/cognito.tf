# Amazon Cognito User Pool
# ALB の authenticate-oidc で使う OIDC プロバイダーとして Cognito を Terraform 管理する。
# use_cognito = true の場合のみリソースが作成される。
# use_cognito = false にすれば外部 IdP（Google, Auth0 等）を変数指定で使える。

#-------------------------------------------------------------------------------
# User Pool
# メールアドレスでサインインする最小構成。
# Cognito Hosted UI が OIDC の各エンドポイントを自動で提供してくれる。
#-------------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  count = var.use_cognito ? 1 : 0
  name  = "${var.environment}-${var.project_name}-pool"

  # メールアドレスをユーザー名として使用する
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # パスワードリセット等はメールで行う
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-pool"
  }
}

#-------------------------------------------------------------------------------
# User Pool Domain
# Cognito Hosted UI のエンドポイントに使われるドメインプレフィックス。
# https://<prefix>.auth.<region>.amazoncognito.com の形式になる。
# この値は AWS 全体でグローバルに一意である必要がある。
#-------------------------------------------------------------------------------
resource "aws_cognito_user_pool_domain" "main" {
  count        = var.use_cognito ? 1 : 0
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.main[0].id
}

#-------------------------------------------------------------------------------
# User Pool Client（ALB 用）
# ALB の authenticate-oidc アクションが使う OAuth2 クライアント。
#
# ポイント:
# - generate_secret = true が必須（ALB は Confidential Client として動作するため）
# - callback_urls に ALB の固定パス /oauth2/idpresponse を指定する
# - allowed_oauth_flows = ["code"] で Authorization Code Flow を使う
#-------------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "main" {
  count        = var.use_cognito ? 1 : 0
  name         = "${var.environment}-${var.project_name}-alb-client"
  user_pool_id = aws_cognito_user_pool.main[0].id

  # ALB は client_secret を使って token endpoint にアクセスするため必須
  generate_secret = true

  # Authorization Code Flow（ALB が裏で code → token 交換を行う）
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "profile", "email"]
  supported_identity_providers         = ["COGNITO"]

  # ALB が OIDC 認証後にユーザーを返すコールバック URL
  # この /oauth2/idpresponse は ALB が固定で使うパスで変更不可
  callback_urls = ["https://${local.public_hostname}/oauth2/idpresponse"]
  logout_urls   = ["https://${local.public_hostname}"]

  # トークンの有効期間
  access_token_validity  = 1  # 時間
  id_token_validity      = 1  # 時間
  refresh_token_validity = 30 # 日

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

#-------------------------------------------------------------------------------
# OIDC エンドポイントの解決
# Cognito を使う場合はリソースから自動導出し、外部 IdP の場合は変数を使う。
# alb.tf の authenticate-oidc はこの locals を参照する。
#-------------------------------------------------------------------------------
locals {
  # Cognito Hosted UI のベース URL
  cognito_domain_url = var.use_cognito ? "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com" : ""

  # Cognito / 外部 IdP を透過的に切り替える
  resolved_oidc_issuer                 = var.use_cognito ? "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main[0].id}" : var.oidc_issuer
  resolved_oidc_authorization_endpoint = var.use_cognito ? "${local.cognito_domain_url}/oauth2/authorize" : var.oidc_authorization_endpoint
  resolved_oidc_token_endpoint         = var.use_cognito ? "${local.cognito_domain_url}/oauth2/token" : var.oidc_token_endpoint
  resolved_oidc_user_info_endpoint     = var.use_cognito ? "${local.cognito_domain_url}/oauth2/userInfo" : var.oidc_user_info_endpoint
  resolved_oidc_client_id              = var.use_cognito ? aws_cognito_user_pool_client.main[0].id : var.oidc_client_id
  resolved_oidc_client_secret          = var.use_cognito ? aws_cognito_user_pool_client.main[0].client_secret : var.oidc_client_secret
}
