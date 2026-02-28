# ALB DNS名（ブラウザでアクセスするURL）
output "alb_dns_name" {
  description = "ALB DNS name - access this URL to see the Nginx welcome page"
  value       = "http://${aws_lb.main.dns_name}"
}

# ECSクラスター名
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# ECSサービス名
output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

# ECRリポジトリURL（Dockerイメージのプッシュ先）
output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing Docker images"
  value       = aws_ecr_repository.main.repository_url
}

# CloudWatch Logsグループ名
output "cloudwatch_log_group" {
  description = "CloudWatch Logs group name for container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}
