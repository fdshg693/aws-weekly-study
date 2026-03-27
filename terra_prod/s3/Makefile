# Makefile for terra_prod/s3
# S3 static website + backend bootstrap helpers

SHELL := /bin/bash

ENV ?= dev
AWS_REGION ?= ap-northeast-1
TFVARS_FILE := $(ENV).tfvars
BACKEND_DIR := backend
BACKEND_BOOTSTRAP_DIR := backend_bootstrap
BACKEND_FILE := $(BACKEND_DIR)/$(ENV).hcl
BACKEND_EXAMPLE_FILE := $(BACKEND_DIR)/$(ENV).hcl.example

.PHONY: help fmt validate validate-root validate-bootstrap \
	bootstrap-init bootstrap-fmt bootstrap-validate bootstrap-plan bootstrap-apply bootstrap-output \
	backend-dev backend-prod backend-copy init-local init plan apply destroy output output-json clean

help: ## コマンド一覧を表示
	@echo ""
	@echo "使い方: make <target> [ENV=dev|prod]"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "初回セットアップのおすすめ手順:"
	@echo "  1. make bootstrap-apply"
	@echo "  2. make bootstrap-output"
	@echo "  3. make backend-dev   # dev.hcl を作る場合"
	@echo "  4. make init ENV=dev"
	@echo "  5. make plan ENV=dev"
	@echo "  6. make apply ENV=dev"
	@echo ""
	@echo "本番環境の例:"
	@echo "  make backend-prod"
	@echo "  make init ENV=prod"
	@echo "  make plan ENV=prod"

fmt: ## Terraform コードをまとめて整形
	@echo "🎨 Formatting Terraform code..."
	terraform fmt -recursive

validate: validate-root validate-bootstrap ## 本体とbootstrapの両方を検証

validate-root: ## 本体Terraform設定を検証（backend未接続でも可）
	@echo "✅ Validating root Terraform configuration..."
	terraform init -backend=false >/dev/null
	terraform validate

validate-bootstrap: ## backend bootstrap設定を検証
	@echo "✅ Validating backend bootstrap configuration..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform init -backend=false >/dev/null && terraform validate

bootstrap-init: ## backend bootstrap用 Terraform を初期化
	@echo "🔧 Initializing backend bootstrap..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform init

bootstrap-fmt: ## backend bootstrap配下だけ整形
	@echo "🎨 Formatting backend bootstrap code..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform fmt -recursive

bootstrap-validate: bootstrap-init ## backend bootstrap設定を検証
	@echo "✅ Validating backend bootstrap..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform validate

bootstrap-plan: bootstrap-init ## backend用S3/DynamoDBのplanを表示
	@echo "📋 Planning backend bootstrap resources..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform plan

bootstrap-apply: bootstrap-init ## backend用S3/DynamoDBを作成
	@echo "🚀 Applying backend bootstrap resources..."
	cd $(BACKEND_BOOTSTRAP_DIR) && terraform apply

bootstrap-output: bootstrap-init ## backend bootstrapのoutputを表示
	@echo "📤 Backend bootstrap outputs:"
	@cd $(BACKEND_BOOTSTRAP_DIR) && terraform output

backend-copy: ## ENV に応じた backend/*.hcl を example から作成
	@if [ ! -f "$(BACKEND_EXAMPLE_FILE)" ]; then \
		echo "❌ Example file not found: $(BACKEND_EXAMPLE_FILE)"; \
		exit 1; \
	fi
	@if [ -f "$(BACKEND_FILE)" ]; then \
		echo "⚠️  Already exists: $(BACKEND_FILE)"; \
		echo "   Edit it manually if you want to change the values."; \
	else \
		cp "$(BACKEND_EXAMPLE_FILE)" "$(BACKEND_FILE)"; \
		echo "✅ Created $(BACKEND_FILE)"; \
		echo "   Fill in bucket / dynamodb_table using 'make bootstrap-output'."; \
	fi

backend-dev: ## backend/dev.hcl を example から作成
	@$(MAKE) backend-copy ENV=dev

backend-prod: ## backend/prod.hcl を example から作成
	@$(MAKE) backend-copy ENV=prod

init-local: ## backend未使用で本体Terraformを初期化
	@echo "🔧 Initializing Terraform without backend..."
	terraform init -backend=false

init: ## backend付きで本体Terraformを初期化
	@if [ ! -f "$(BACKEND_FILE)" ]; then \
		echo "❌ Backend config not found: $(BACKEND_FILE)"; \
		echo "   Run 'make backend-$(ENV)' first, then edit the generated file."; \
		exit 1; \
	fi
	@echo "🔧 Initializing Terraform with backend config: $(BACKEND_FILE)"
	terraform init -backend-config="$(BACKEND_FILE)" -reconfigure

plan: init ## 本体のTerraform planを表示
	@echo "📋 Planning $(ENV) environment..."
	terraform plan -var-file="$(TFVARS_FILE)"

apply: init ## 本体のTerraform applyを実行
	@echo "🚀 Applying $(ENV) environment..."
	@if [ "$(ENV)" = "prod" ]; then \
		echo "⚠️  WARNING: This will deploy to PRODUCTION!"; \
		read -p "Are you sure? [y/N] " -n 1 -r; \
		echo ""; \
		if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
			echo "Cancelled."; \
			exit 1; \
		fi; \
		terraform apply -var-file="$(TFVARS_FILE)"; \
	else \
		terraform apply -var-file="$(TFVARS_FILE)" -auto-approve; \
	fi

destroy: init ## 本体のTerraform destroyを実行
	@echo "💥 Destroying $(ENV) environment..."
	@if [ "$(ENV)" = "prod" ]; then \
		echo "⚠️  WARNING: This will DELETE production resources!"; \
		read -p "Are you sure? [y/N] " -n 1 -r; \
		echo ""; \
		if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
			echo "Cancelled."; \
			exit 1; \
		fi; \
	fi
	terraform destroy -var-file="$(TFVARS_FILE)"

output: ## 本体Terraformのoutputを表示
	@terraform output

output-json: ## 本体TerraformのoutputをJSON表示
	@terraform output -json

clean: ## Terraformのローカル一時ファイルを削除
	@echo "🧹 Cleaning local Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate
	rm -f terraform.tfstate.backup

.DEFAULT_GOAL := help
