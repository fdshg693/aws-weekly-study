terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # moved ブロック（state mv）を使うため v1.1 以上
  required_version = ">= 1.1"
}

# AWSプロバイダー設定
# - 実行環境の認証は AWS CLI の設定（環境変数 / ~/.aws/credentials）を利用する想定
provider "aws" {
  region = var.aws_region

  # AWS CLIプロファイルを使いたい場合は有効化
  # profile = var.aws_profile

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "Kendra-WebCrawler"
      Environment = var.environment
      CreatedBy   = "terraform/kendra"
    }
  }
}
