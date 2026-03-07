output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "public_hostname" {
  description = "Preferred public host name (custom domain if set, otherwise ALB DNS)"
  value       = local.public_hostname
}

output "https_base_url" {
  description = "Base HTTPS URL of the service"
  value       = "https://${local.public_hostname}"
}

output "mcp_url" {
  description = "Public MCP endpoint URL"
  value       = "https://${local.public_hostname}${var.mcp_path}"
}

output "health_url" {
  description = "Health endpoint URL"
  value       = "https://${local.public_hostname}/health"
}

output "oidc_redirect_uri" {
  description = "Callback URL that must be registered on the OIDC provider"
  value       = "https://${local.public_hostname}/oauth2/idpresponse"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID（use_cognito = true の場合のみ）"
  value       = var.use_cognito ? aws_cognito_user_pool.main[0].id : null
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI のベース URL"
  value       = var.use_cognito ? "https://${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com" : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker push"
  value       = aws_ecr_repository.main.repository_url
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}
