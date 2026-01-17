# ============================================
# Terraform設定
# ============================================
# Terraformのバージョンと必要なプロバイダーを定義します
# この設定により、プロジェクトで使用するプロバイダーのバージョンを管理できます

terraform {
  # Terraformのバージョン要件
  # ~> 1.0: 1.0.x系の最新版を使用（1.1.0は使用しない）
  required_version = ">= 1.0"

  # 必要なプロバイダーの設定
  required_providers {
    # AWSプロバイダー
    # - source: プロバイダーの提供元（HashiCorp公式）
    # - version: 使用するバージョンの制約
    #   ~> 5.0: 5.x系の最新版を使用（メジャーバージョンアップは含まない）
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Randomプロバイダー
    # - Secrets Managerのシークレット名にランダムな接尾辞を追加するために使用
    # - シークレット削除後の再作成を容易にする
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # ========================================
  # バックエンド設定（オプション）
  # ========================================
  # Terraformの状態ファイル（terraform.tfstate）の保存場所を設定
  # 
  # オプション:
  # 1. local（デフォルト）: ローカルファイルシステムに保存
  #    - メリット: 設定不要、シンプル
  #    - デメリット: チーム開発に不向き、状態ファイルの損失リスク
  # 
  # 2. s3: AWS S3に保存（推奨）
  #    - メリット: チーム開発に最適、状態ファイルのロック機能（DynamoDBと併用）
  #    - 設定例:
  #      backend "s3" {
  #        bucket         = "my-terraform-state"
  #        key            = "discord-bot/terraform.tfstate"
  #        region         = "ap-northeast-1"
  #        encrypt        = true
  #        dynamodb_table = "terraform-state-lock"
  #      }
  # 
  # 3. terraform cloud: Terraform Cloudに保存
  #    - メリット: リモート実行、変更履歴の管理、コラボレーション機能
  #
  # ベストプラクティス:
  # - 本番環境ではS3バックエンドの使用を推奨
  # - 学習・開発環境ではローカルバックエンドでも可
}

# ============================================
# AWSプロバイダー設定
# ============================================
# AWS APIとの接続設定を定義します
# この設定により、Terraformがどのリージョンでリソースを作成するかを指定できます

provider "aws" {
  # リージョン設定
  # 変数を使用することで、環境ごとに異なるリージョンを簡単に指定可能
  region = var.aws_region

  # ========================================
  # タグのデフォルト設定（オプション）
  # ========================================
  # すべてのリソースに自動的に適用されるタグ
  # プロジェクト管理やコスト管理に有用
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      # CreatedAt = timestamp() # 注意: timestampは毎回変更されるため非推奨
    }
  }

  # ========================================
  # その他の利用可能なオプション
  # ========================================
  # 
  # 1. プロファイル指定（複数のAWSアカウントを使用する場合）
  #    profile = "my-profile"
  # 
  # 2. 認証情報の明示的指定（非推奨：セキュリティリスクあり）
  #    access_key = "YOUR_ACCESS_KEY"
  #    secret_key = "YOUR_SECRET_KEY"
  #    ※ 環境変数やIAMロールの使用を推奨
  # 
  # 3. AssumeRoleの使用（クロスアカウントアクセス）
  #    assume_role {
  #      role_arn = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  #    }
  # 
  # 4. エンドポイントのカスタマイズ（LocalStackなどのテスト環境）
  #    endpoints {
  #      s3  = "http://localhost:4566"
  #      ec2 = "http://localhost:4566"
  #    }
  # 
  # ベストプラクティス:
  # - 認証情報はコードに含めず、環境変数やAWS CLIの設定を使用
  # - 本番環境ではIAMロールの使用を推奨
  # - タグを使用してリソースを適切に管理
}
