terraform {
  # Terraformで使用するプロバイダーの要件を定義
  # プロバイダーはTerraformがクラウドサービスと通信するためのプラグイン
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # バージョン制約: ~> は指定されたマイナーバージョン内での最新パッチバージョンを使用
      # 例: ~> 6.0 は 6.0.x の最新版を使用（6.1.0 は使用しない）
      version = "~> 6.0"
    }
    
    # Lambda関数のZIPファイル作成に使用
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  
  # Terraform自体の最小バージョン要件
  # この設定により、古いTerraformバージョンでの実行を防ぐ
  required_version = ">= 1.0"
}

# AWSプロバイダーの設定
provider "aws" {
  # デプロイ先のAWSリージョン
  # 変数を使用することで環境ごとに変更可能
  region = var.aws_region
  
  # プロファイル名（AWS CLIの設定を使用する場合）
  # profile = var.aws_profile
  
  # 全てのリソースに共通で付与されるタグ
  # これにより管理・コスト追跡が容易になる
  default_tags {
    tags = {
      ManagedBy   = "Terraform"           # Terraformで管理されていることを示す
      Project     = "Lambda-Sample"       # プロジェクト名
      Environment = var.environment       # 環境（dev/staging/prod）
      CreatedBy   = "terraform/lambda"    # 作成元の情報
    }
  }
}

# Archiveプロバイダーの設定
# Lambda関数のソースコードをZIPファイルにアーカイブする際に使用
provider "archive" {
  # 特別な設定は不要（デフォルト設定を使用）
}
