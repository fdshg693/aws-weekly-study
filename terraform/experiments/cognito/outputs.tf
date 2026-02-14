# Output Values
# =============
# 作成されたCognitoリソースの情報を出力します。
# これらの値は、CURL/Postmanでのテストやアプリケーション設定に使用します。

# ========================================
# User Pool Information
# ========================================

output "user_pool_id" {
  description = "Cognito User Pool ID（ユーザープールの一意な識別子）"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN（IAMポリシーでの参照に使用）"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_name" {
  description = "Cognito User Pool Name"
  value       = aws_cognito_user_pool.main.name
}

output "user_pool_endpoint" {
  description = "Cognito User Pool Endpoint（API呼び出しのベースURL）"
  value       = aws_cognito_user_pool.main.endpoint
}

# ========================================
# User Pool Client Information
# ========================================

output "user_pool_client_id" {
  description = "Cognito User Pool Client ID（アプリケーションの認証に必要）"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_client_name" {
  description = "Cognito User Pool Client Name"
  value       = aws_cognito_user_pool_client.main.name
}

output "user_pool_client_secret" {
  description = "Cognito User Pool Client Secret（BFFでのトークン交換に必要。機密情報）"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

# ========================================
# User Pool Domain
# ========================================

output "user_pool_domain" {
  description = "Cognito User Pool Domain（Hosted UIのURL）"
  value       = var.create_user_pool_domain ? aws_cognito_user_pool_domain.main[0].domain : null
}

output "user_pool_domain_cloudfront" {
  description = "Cognito User Pool Domain CloudFront Distribution（Hosted UIのフルURL）"
  value       = var.create_user_pool_domain ? aws_cognito_user_pool_domain.main[0].cloudfront_distribution : null
}

output "hosted_ui_url" {
  description = "Hosted UIのログインURL（ブラウザでアクセス可能）"
  value = var.create_user_pool_domain ? (
    "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com/login"
  ) : null
}

# ========================================
# Testing Information
# ========================================

output "aws_region" {
  description = "デプロイされたAWSリージョン"
  value       = var.aws_region
}

output "cognito_idp_endpoint" {
  description = "Cognito Identity Provider エンドポイント（CURL/APIテスト用）"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com"
}

# ========================================
# Quick Test Command Templates
# ========================================

output "test_commands_info" {
  description = "CURLテストコマンドのテンプレート情報"
  value = {
    region          = var.aws_region
    user_pool_id    = aws_cognito_user_pool.main.id
    client_id       = aws_cognito_user_pool_client.main.id
    idp_endpoint    = "https://cognito-idp.${var.aws_region}.amazonaws.com"
    hosted_ui_url   = var.create_user_pool_domain ? "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com/login" : "N/A"
  }
}

# ========================================
# Deployed URLs
# ========================================

output "deployed_urls" {
  description = "デプロイされたURLの一覧"
  value = {
    amplify_app      = "https://main.${aws_amplify_app.frontend.default_domain}"
    bff_api          = aws_apigatewayv2_stage.bff.invoke_url
    hosted_ui        = var.create_user_pool_domain ? "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com/login" : null
    cognito_endpoint = "https://cognito-idp.${var.aws_region}.amazonaws.com"
  }
}

# ========================================
# Summary
# ========================================

output "deployment_summary" {
  description = "デプロイメントのサマリー情報"
  value = {
    environment         = var.environment
    project_name        = var.project_name
    user_pool_id        = aws_cognito_user_pool.main.id
    client_id           = aws_cognito_user_pool_client.main.id
    region              = var.aws_region
    mfa_enabled         = var.mfa_configuration
    self_registration   = var.enable_self_registration
    hosted_ui_available = var.create_user_pool_domain
  }
}

# ========================================
# Amplify Hosting
# ========================================

output "amplify_app_id" {
  description = "Amplify App ID（手動デプロイに使用）"
  value       = aws_amplify_app.frontend.id
}

output "amplify_default_domain" {
  description = "Amplify デフォルトドメイン"
  value       = aws_amplify_app.frontend.default_domain
}

output "amplify_app_url" {
  description = "Amplify アプリケーションURL（ブラウザでアクセス可能）"
  value       = "https://main.${aws_amplify_app.frontend.default_domain}"
}

# ========================================
# BFF Lambda + API Gateway
# ========================================

output "bff_api_url" {
  description = "BFF API Gateway URL（フロントエンドからのAPI呼び出し先）"
  value       = aws_apigatewayv2_stage.bff.invoke_url
}

output "bff_lambda_function_name" {
  description = "BFF Lambda関数名（ログ確認等に使用）"
  value       = aws_lambda_function.bff.function_name
}

output "bff_dynamodb_table_name" {
  description = "BFFセッション用DynamoDBテーブル名"
  value       = aws_dynamodb_table.bff_sessions.name
}
