# 変数の定義（環境ごとに dev.tfvars / prod.tfvars で値を切り替える想定）

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Region must be valid AWS region format (e.g., ap-northeast-1)."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

# Kendra Index
variable "kendra_index_name" {
  description = "Kendra index name"
  type        = string
}

variable "kendra_index_description" {
  description = "Kendra index description"
  type        = string
  default     = "Kendra index managed by Terraform"
}

variable "kendra_edition" {
  description = "Kendra edition: DEVELOPER_EDITION or ENTERPRISE_EDITION"
  type        = string
  default     = "DEVELOPER_EDITION"

  validation {
    condition     = contains(["DEVELOPER_EDITION", "ENTERPRISE_EDITION"], var.kendra_edition)
    error_message = "kendra_edition must be one of: DEVELOPER_EDITION, ENTERPRISE_EDITION."
  }
}

# Web Crawler Data Source
variable "data_source_name" {
  description = "Kendra data source name"
  type        = string
  default     = "webcrawler"
}

variable "seed_urls" {
  description = "Seed URLs for the web crawler (e.g., https://example.com, https://example.com/docs)"
  type        = list(string)

  validation {
    condition     = length(var.seed_urls) > 0
    error_message = "seed_urls must contain at least one URL."
  }
}

variable "web_crawler_mode" {
  description = "Web crawler mode for seed URLs (e.g., HOST_ONLY, SUBDOMAINS)"
  type        = string
  default     = "HOST_ONLY"
}

variable "url_inclusion_patterns" {
  description = "List of regex patterns to include URLs (optional)"
  type        = list(string)
  default     = []
}

variable "url_exclusion_patterns" {
  description = "List of regex patterns to exclude URLs (optional)"
  type        = list(string)
  default     = []
}

variable "schedule" {
  description = "Kendra data source sync schedule (EventBridge cron expression). Set null to disable scheduled sync."
  type        = string
  default     = null
}
