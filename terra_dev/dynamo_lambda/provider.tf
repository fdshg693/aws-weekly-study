terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        ManagedBy   = "Terraform"
        Project     = var.project_name
        Environment = var.environment
        CreatedBy   = "terraform/dynamo_lambda"
      },
      var.additional_tags,
    )
  }
}