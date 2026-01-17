terraform {
  # ここで使用するプロバイダーを定義
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # 使用するAWSリージョンを指定
  region = var.aws_region
  # 全てのリソースに共通で付与するタグを設定
  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}