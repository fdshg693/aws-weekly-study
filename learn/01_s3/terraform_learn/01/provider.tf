# Terraformプロバイダー設定
#
# 学習ポイント：
# - AWS Providerの設定
# - マルチリージョン対応（エイリアス）
# - バックエンド設定（状態ファイル管理）
# - プロバイダーバージョン制約

terraform {
  # Terraformバージョン制約
  required_version = ">= 1.5.0"

  # 必要なプロバイダー
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # null_resource用
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    # 外部データソース用
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }

  # バックエンド設定例：S3に状態ファイルを保存
  # 本番環境では必須（チーム開発・CI/CD対応）
  # backend "s3" {
  #   bucket         = "terraform-state-bucket-YOUR-ACCOUNT-ID"
  #   key            = "static-website/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }

  # ローカルバックエンド（デフォルト）
  # terraform.tfstate ファイルがローカルに保存される
}

# デフォルトプロバイダー（メインリージョン）
provider "aws" {
  region = var.aws_region

  # デフォルトタグ：全リソースに自動付与
  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        Region      = var.aws_region
      }
    )
  }

  # プロファイル指定（AWS CLI設定使用）
  # profile = "default"

  # 認証情報の明示的指定（非推奨：環境変数推奨）
  # access_key = "YOUR_ACCESS_KEY"
  # secret_key = "YOUR_SECRET_KEY"
}

# us-east-1プロバイダー（CloudFront用ACM証明書）
# CloudFrontはus-east-1のACM証明書のみ使用可能
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        Region      = "us-east-1"
        Purpose     = "CloudFront Certificate"
      }
    )
  }
}

# 複数アカウント対応例（クロスアカウント）
# provider "aws" {
#   alias  = "production"
#   region = var.aws_region
#   
#   assume_role {
#     role_arn = "arn:aws:iam::123456789012:role/TerraformRole"
#   }
# }

# Providerの使い分け例
# resource "aws_acm_certificate" "cert" {
#   provider = aws.us_east_1  # エイリアス指定
#   domain_name = "example.com"
#   ...
# }
