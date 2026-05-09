variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used as the prefix for resource names"
  type        = string
  default     = "prompt-manager"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "project_name must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, or prod."
  }
}

variable "lambda_memory_size" {
  description = "Memory size for the prompt API Lambda function"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout in seconds for the prompt API Lambda function"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 14
}

variable "default_prompt_list_limit" {
  description = "Default limit value used by the Lambda function for GET /prompts"
  type        = number
  default     = 20
}

variable "max_prompt_list_limit" {
  description = "Maximum limit value allowed by the Lambda function for GET /prompts"
  type        = number
  default     = 100
}

variable "cors_allow_origin" {
  description = "Value returned in Access-Control-Allow-Origin headers"
  type        = string
  default     = "*"
}

variable "additional_tags" {
  description = "Additional tags merged into resources and provider default tags"
  type        = map(string)
  default     = {}
}