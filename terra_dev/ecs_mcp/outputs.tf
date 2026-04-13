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

output "keycloak_base_url" {
  description = "Keycloak base URL used by the MCP authorization flow"
  value       = local.keycloak_base_url
}

output "keycloak_realm_url" {
  description = "Keycloak realm URL used by the MCP authorization flow"
  value       = local.keycloak_realm_url
}

output "keycloak_openid_configuration_url" {
  description = "Keycloak OIDC discovery URL"
  value       = "${local.keycloak_realm_url}/.well-known/openid-configuration"
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

output "keycloak_admin_console_url" {
  description = "Keycloak admin console URL when deploy_keycloak_on_aws = true"
  value       = var.deploy_keycloak_on_aws ? "${local.keycloak_base_url}/admin/" : null
}

output "keycloak_ecs_service_name" {
  description = "Keycloak ECS service name when deploy_keycloak_on_aws = true"
  value       = var.deploy_keycloak_on_aws ? aws_ecs_service.keycloak[0].name : null
}

output "keycloak_database_endpoint" {
  description = "Keycloak PostgreSQL endpoint when deploy_keycloak_on_aws = true"
  value       = var.deploy_keycloak_on_aws ? aws_db_instance.keycloak[0].address : null
}

#-------------------------------------------------------------------------------
# Claude Desktop 連携情報（enable_server_oauth = true の場合のみ）
#-------------------------------------------------------------------------------
output "claude_desktop_client_id" {
  description = "Claude Desktop の Connector 設定で使う public client ID（事前登録運用時のみ）"
  value       = var.enable_server_oauth && !var.keycloak_enable_dynamic_client_registration ? var.keycloak_public_client_id : null
}

output "claude_desktop_connector_url" {
  description = "Claude Desktop の Settings > Connectors に登録する URL"
  value       = var.enable_server_oauth ? "https://${local.public_hostname}${var.mcp_path}" : null
}

output "keycloak_registration_endpoint" {
  description = "Keycloak Dynamic Client Registration endpoint（有効時のみ）"
  value       = var.keycloak_enable_dynamic_client_registration ? local.resolved_oidc_registration_endpoint : null
}
