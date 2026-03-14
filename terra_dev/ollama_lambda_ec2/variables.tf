variable "aws_region" {
  description = "AWS region where this standalone sample project is deployed."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "ollama-lambda-ec2"
}

variable "environment" {
  description = "Deployment environment name. This sample supports dev and prod."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either dev or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the Ollama server."
  type        = string
}

variable "default_model" {
  description = "Default Ollama model name used when the caller omits model."
  type        = string
  default     = "qwen2.5:0.5b"
}

variable "shared_api_secret" {
  description = "Shared API secret stored in Secrets Manager and validated by Lambda. The plaintext will also be stored in Terraform state when secret_version is managed by Terraform."
  type        = string
  sensitive   = true
}

variable "ollama_port" {
  description = "TCP port where Ollama listens on the EC2 instance."
  type        = number
  default     = 11434
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds. Keep below the synchronous API Gateway integration ceiling."
  type        = number
  default     = 29

  validation {
    condition     = var.lambda_timeout_seconds >= 5 && var.lambda_timeout_seconds <= 29
    error_message = "lambda_timeout_seconds must be between 5 and 29 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Memory size in MB for the Lambda proxy function."
  type        = number
  default     = 1024
}

variable "lambda_log_retention_days" {
  description = "Retention period for the Lambda CloudWatch log group."
  type        = number
  default     = 14
}

variable "api_access_log_retention_days" {
  description = "Retention period for API Gateway access logs."
  type        = number
  default     = 14
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for the EC2 instance."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root EBS volume type for the EC2 instance."
  type        = string
  default     = "gp3"
}

variable "secret_recovery_window_in_days" {
  description = "Secrets Manager recovery window when the secret is deleted. Set 7 to keep the default safety net."
  type        = number
  default     = 7
}

locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  default_subnet_ids   = sort(data.aws_subnets.default.ids)
  ec2_subnet_id        = local.default_subnet_ids[0]
  vpc_dns_resolver_ip  = cidrhost(data.aws_vpc.default.cidr_block, 2)
  lambda_function_name = "${local.name_prefix}-proxy"
  common_name_tags = {
    ProjectComponent = var.project_name
  }
}
