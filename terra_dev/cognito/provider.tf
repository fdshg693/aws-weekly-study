# Terraform Provider Configuration
# ==============================
# Terraformのバージョンとプロバイダーの設定を行います。
# AWS Provider version 6.x系を使用し、Terraform 1.0以上が必要です。
#
# default_tags:
#   全てのリソースに自動的に付与されるタグを設定します。
#   これにより、コスト管理やリソース追跡が容易になります。

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = var.environment
      CreatedBy   = "terraform/cognito"
    }
  }
}
