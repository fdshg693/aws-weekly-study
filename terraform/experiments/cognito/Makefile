# Makefile for Cognito Terraform Project
# =======================================
# 便利なコマンドショートカットを提供します
#
# 使用方法:
#   make help     - ヘルプを表示
#   make init     - Terraform初期化
#   make plan     - デプロイ計画を表示（開発環境）
#   make apply    - デプロイ実行（開発環境）
#   make destroy  - リソース削除（開発環境）
#   make test     - 認証フローテスト

.PHONY: help init fmt validate plan apply destroy output test clean plan-prod apply-prod destroy-prod frontend-install frontend-dev frontend-build frontend-deploy

# デフォルトの環境設定
ENV ?= dev
REGION ?= ap-northeast-1

help: ## ヘルプを表示
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage examples:"
	@echo "  make plan          - 開発環境のプランを表示"
	@echo "  make apply         - 開発環境にデプロイ"
	@echo "  make plan-prod     - 本番環境のプランを表示"
	@echo "  make apply-prod    - 本番環境にデプロイ"
	@echo "  make test          - 認証フローテスト"
	@echo "  make output        - 出力値を表示"

init: ## Terraform初期化
	@echo "🔧 Initializing Terraform..."
	terraform init

fmt: ## コードフォーマット
	@echo "🎨 Formatting Terraform code..."
	terraform fmt -recursive

validate: ## 設定の検証
	@echo "✅ Validating Terraform configuration..."
	terraform validate

plan: init ## デプロイ計画を表示（開発環境）
	@echo "📋 Planning deployment for dev environment..."
	terraform plan -var-file="dev.tfvars"

apply: init ## デプロイ実行（開発環境）
	@echo "🚀 Applying Terraform configuration for dev environment..."
	terraform apply -var-file="dev.tfvars"

destroy: ## リソース削除（開発環境）
	@echo "💥 Destroying dev environment resources..."
	terraform destroy -var-file="dev.tfvars"

plan-prod: init ## デプロイ計画を表示（本番環境）
	@echo "📋 Planning deployment for production environment..."
	terraform plan -var-file="prod.tfvars"

apply-prod: init ## デプロイ実行（本番環境）
	@echo "🚀 Applying Terraform configuration for production environment..."
	@echo "⚠️  WARNING: This will deploy to PRODUCTION!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform apply -var-file="prod.tfvars"; \
	else \
		echo "Cancelled."; \
	fi

destroy-prod: ## リソース削除（本番環境）
	@echo "💥 Destroying production environment resources..."
	@echo "⚠️  WARNING: This will DELETE production resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform destroy -var-file="prod.tfvars"; \
	else \
		echo "Cancelled."; \
	fi

output: ## 出力値を表示
	@echo "📤 Terraform outputs:"
	@terraform output

output-json: ## 出力値をJSON形式で表示
	@terraform output -json

test: ## 認証フローテスト
	@echo "🧪 Running authentication flow test..."
	@if [ ! -f test_auth_flow.sh ]; then \
		echo "❌ test_auth_flow.sh not found"; \
		exit 1; \
	fi
	@chmod +x test_auth_flow.sh
	@./test_auth_flow.sh

clean: ## Terraformの一時ファイルを削除
	@echo "🧹 Cleaning up Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup

show: ## 現在の状態を表示
	@terraform show

graph: ## リソースの依存関係グラフを生成
	@echo "📊 Generating dependency graph..."
	@terraform graph | dot -Tpng > graph.png
	@echo "Graph saved to graph.png"

console: ## Terraform consoleを起動
	@terraform console

# ユーティリティコマンド
get-pool-id: ## User Pool IDを取得
	@terraform output -raw user_pool_id

get-client-id: ## Client IDを取得
	@terraform output -raw user_pool_client_id

get-region: ## Regionを取得
	@terraform output -raw aws_region

set-env: ## 環境変数を設定（source使用）
	@echo "⚠️  Run this command with 'source' or '.'"
	@echo "Example: source <(make set-env)"
	@echo ""
	@echo "export REGION=$$(terraform output -raw aws_region)"
	@echo "export USER_POOL_ID=$$(terraform output -raw user_pool_id)"
	@echo "export CLIENT_ID=$$(terraform output -raw user_pool_client_id)"

all: fmt validate plan ## フォーマット、検証、プランを実行

# ========================================
# Frontend Commands
# ========================================

frontend-install: ## フロントエンドの依存関係をインストール
	@echo "📦 Installing frontend dependencies..."
	cd frontend && npm install

frontend-dev: ## フロントエンド開発サーバーを起動（localhost:5173）
	@echo "🔧 Starting frontend dev server..."
	cd frontend && npm run dev

frontend-build: ## フロントエンドをビルド
	@echo "🔨 Building frontend..."
	cd frontend && npm run build

frontend-deploy: frontend-build ## フロントエンドをAmplifyにデプロイ
	@echo "🚀 Deploying frontend to Amplify..."
	@APP_ID=$$(terraform output -raw amplify_app_id) && \
	cd frontend/dist && zip -r /tmp/amplify-deploy.zip . && \
	DEPLOY_INFO=$$(aws amplify create-deployment --app-id $$APP_ID --branch-name main --region $(REGION) --output json) && \
	UPLOAD_URL=$$(echo $$DEPLOY_INFO | python3 -c "import sys,json; print(json.load(sys.stdin)['zipUploadUrl'])") && \
	JOB_ID=$$(echo $$DEPLOY_INFO | python3 -c "import sys,json; print(json.load(sys.stdin)['jobId'])") && \
	curl -s --request PUT --upload-file /tmp/amplify-deploy.zip "$$UPLOAD_URL" > /dev/null && \
	aws amplify start-deployment --app-id $$APP_ID --branch-name main --job-id $$JOB_ID --region $(REGION) > /dev/null && \
	rm -f /tmp/amplify-deploy.zip && \
	echo "✅ Deployed to: $$(terraform output -raw amplify_app_url)"

.DEFAULT_GOAL := help
