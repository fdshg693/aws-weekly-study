# Keycloak を OIDC / OAuth 認可サーバーとして利用するための共通 locals。
# deploy_keycloak_on_aws = true の場合は、この Terraform が AWS 上に構築した Keycloak を参照する。
# false の場合は、既存または別途構築した外部 Keycloak を参照する。

locals {
  keycloak_base_url  = trimsuffix(var.deploy_keycloak_on_aws ? "https://${local.public_hostname}${var.keycloak_path}" : var.keycloak_base_url, "/")
  keycloak_realm_url = "${local.keycloak_base_url}/realms/${var.keycloak_realm}"

  resolved_oidc_issuer                 = local.keycloak_realm_url
  resolved_oidc_authorization_endpoint = "${local.keycloak_realm_url}/protocol/openid-connect/auth"
  resolved_oidc_token_endpoint         = "${local.keycloak_realm_url}/protocol/openid-connect/token"
  resolved_oidc_user_info_endpoint     = "${local.keycloak_realm_url}/protocol/openid-connect/userinfo"
  resolved_oidc_registration_endpoint  = var.keycloak_enable_dynamic_client_registration ? "${local.keycloak_base_url}/realms/${var.keycloak_realm}/clients-registrations/openid-connect" : ""
  resolved_oidc_introspection_endpoint = "${local.keycloak_realm_url}/protocol/openid-connect/token/introspect"
  resolved_oidc_scopes                 = length(var.oauth_supported_scopes) > 0 ? var.oauth_supported_scopes : ["mcp:tools"]
  resolved_expected_audiences          = length(var.keycloak_expected_audiences) > 0 ? var.keycloak_expected_audiences : ["https://${local.public_hostname}${var.mcp_path}"]
}
