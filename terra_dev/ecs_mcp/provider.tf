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

  # このプロジェクトで作るリソースに共通タグを付ける。
  # 学習用サンプルでもタグを揃えておくと、AWSコンソール上で追いやすい。
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "ECS-MCP-Sample"
      Environment = var.environment
      CreatedBy   = "terraform/ecs_mcp"
    }
  }
}
