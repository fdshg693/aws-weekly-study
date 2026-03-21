# Makefile for ollama_lambda_ec2
# Terraform + Ansible + curl test helpers

SHELL := /bin/bash

ENV ?= dev
REGION ?= ap-northeast-1
PROMPT ?= こんにちは、自己紹介して
MODEL ?= qwen2.5:0.5b
TFVARS_FILE := $(ENV).tfvars
ANSIBLE_DIR := ansible
ANSIBLE_LIMIT := tag_$(ENV)
ANSIBLE_SSM_BUCKET_PREFIX ?= ollama-lambda-ec2-ssm
ANSIBLE_RUNNER ?= docker
ANSIBLE_IMAGE_NAME ?= ollama-lambda-ec2-ansible-runner
ANSIBLE_IMAGE_TAG ?= latest
ANSIBLE_IMAGE := $(ANSIBLE_IMAGE_NAME):$(ANSIBLE_IMAGE_TAG)
ANSIBLE_DOCKERFILE := docker/ansible-runner/Dockerfile
ANSIBLE_AWS_DIR ?= $(HOME)/.aws

.PHONY: help init fmt validate plan apply destroy output output-json url secret-name ansible-image ansible-install ansible-inventory ansible-bucket-name ansible-shell ansible test curl-test up down clean

help: ## コマンド一覧を表示
	@echo ""
	@echo "使い方: make <target> [ENV=dev|prod] [REGION=ap-northeast-1]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "よく使う例:"
	@echo "  make plan                     # dev 環境の Terraform plan"
	@echo "  make apply                    # dev 環境を apply"
	@echo "  make ansible-image            # Docker 版 Ansible ランナーを build"
	@echo "  make ansible                  # dev EC2 に Ollama を導入"
	@echo "  make test                     # API 疎通確認"
	@echo "  make up                       # apply -> ansible -> test をまとめて実行"
	@echo "  make destroy ENV=prod         # prod 環境を削除"
	@echo ""
	@echo "Ansible 実行モード:"
	@echo "  make ansible                  # Docker ランナーを使う (既定)"
	@echo "  make ansible ANSIBLE_RUNNER=local  # ローカルの Ansible を使う"
	@echo ""
	@echo "API テストの上書き例:"
	@echo "  make test PROMPT='俳句を1つ作って' MODEL='qwen2.5:0.5b'"

init: ## Terraform を初期化
	@echo "🔧 Initializing Terraform..."
	terraform init

fmt: ## Terraform コードを整形
	@echo "🎨 Formatting Terraform code..."
	terraform fmt -recursive

validate: init ## Terraform 設定を検証
	@echo "✅ Validating Terraform configuration..."
	terraform validate

plan: init ## Terraform plan を表示
	@echo "📋 Planning $(ENV) environment..."
	terraform plan -var-file="$(TFVARS_FILE)"

apply: init ## Terraform apply を実行
	@echo "🚀 Applying Terraform for $(ENV) environment..."
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

destroy: ## Terraform destroy を実行
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

output: ## Terraform outputs を表示
	@terraform output

output-json: ## Terraform outputs を JSON で表示
	@terraform output -json

url: ## generate_url を表示
	@terraform output -raw generate_url

secret-name: ## Secrets Manager のシークレット名を表示
	@terraform output -raw shared_api_secret_name

ansible-image: ## Docker 版 Ansible ランナーイメージを build
	@echo "🐳 Building Ansible runner image $(ANSIBLE_IMAGE)..."
	docker build -f $(ANSIBLE_DOCKERFILE) -t $(ANSIBLE_IMAGE) .

ansible-install: ## Ansible 実行環境を準備
ifeq ($(ANSIBLE_RUNNER),docker)
	@echo "📦 Preparing Docker-based Ansible runner..."
	@$(MAKE) ansible-image ANSIBLE_IMAGE_NAME="$(ANSIBLE_IMAGE_NAME)" ANSIBLE_IMAGE_TAG="$(ANSIBLE_IMAGE_TAG)"
else
	@echo "📦 Installing local Ansible collections..."
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml
endif

ansible-inventory: ansible-install ## EC2 動的インベントリを表示
	@echo "🛰️  Checking dynamic inventory for $(ENV) via $(ANSIBLE_RUNNER)..."
ifeq ($(ANSIBLE_RUNNER),docker)
	@AWS_MOUNT_ARGS=""; \
	if [ -d "$(ANSIBLE_AWS_DIR)" ]; then \
		AWS_MOUNT_ARGS="-v $(ANSIBLE_AWS_DIR):/root/.aws:ro"; \
	fi; \
	docker run --rm \
		-e AWS_PROFILE \
		-e AWS_REGION="$(REGION)" \
		-e AWS_DEFAULT_REGION="$(REGION)" \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e AWS_SDK_LOAD_CONFIG=1 \
		-v "$(CURDIR)":/workspace \
		$$AWS_MOUNT_ARGS \
		-w /workspace/$(ANSIBLE_DIR) \
		"$(ANSIBLE_IMAGE)" \
		ansible-inventory -i inventory.aws_ec2.yml --graph
else
	cd $(ANSIBLE_DIR) && ansible-inventory -i inventory.aws_ec2.yml --graph
endif

ansible-bucket-name: ## Ansible SSM 用の一時 S3 バケット名を表示
	@ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text) && \
		echo "$${ACCOUNT_ID}-$(ANSIBLE_SSM_BUCKET_PREFIX)-$(ENV)-$(REGION)"

ansible-shell: ansible-install ## Docker 版 Ansible ランナーでシェルを開く
ifeq ($(ANSIBLE_RUNNER),docker)
	@echo "🐚 Opening shell in Docker-based Ansible runner..."
	@AWS_MOUNT_ARGS=""; \
	if [ -d "$(ANSIBLE_AWS_DIR)" ]; then \
		AWS_MOUNT_ARGS="-v $(ANSIBLE_AWS_DIR):/root/.aws:ro"; \
	fi; \
	docker run --rm -it \
		-e AWS_PROFILE \
		-e AWS_REGION="$(REGION)" \
		-e AWS_DEFAULT_REGION="$(REGION)" \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e AWS_SDK_LOAD_CONFIG=1 \
		-v "$(CURDIR)":/workspace \
		$$AWS_MOUNT_ARGS \
		-w /workspace/$(ANSIBLE_DIR) \
		"$(ANSIBLE_IMAGE)" \
		bash
else
	@echo "ANSIBLE_RUNNER=local のときは ansible-shell は不要です。"
endif

ansible: ansible-install ## EC2 に Ollama を構築
	@echo "🤖 Running Ansible playbook for $(ENV) via $(ANSIBLE_RUNNER)..."
	@ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text) && \
	BUCKET_NAME=$${ANSIBLE_AWS_SSM_BUCKET:-$${ACCOUNT_ID}-$(ANSIBLE_SSM_BUCKET_PREFIX)-$(ENV)-$(REGION)} && \
	echo "🪣 Using SSM staging bucket: $$BUCKET_NAME" && \
	if ! aws s3api head-bucket --bucket "$$BUCKET_NAME" >/dev/null 2>&1; then \
		echo "🪣 Creating SSM staging bucket..."; \
		if [ "$(REGION)" = "us-east-1" ]; then \
			aws s3api create-bucket --bucket "$$BUCKET_NAME" --region "$(REGION)" >/dev/null; \
		else \
			aws s3api create-bucket --bucket "$$BUCKET_NAME" --region "$(REGION)" --create-bucket-configuration LocationConstraint="$(REGION)" >/dev/null; \
		fi; \
	fi && \
	if [ "$(ANSIBLE_RUNNER)" = "docker" ]; then \
		AWS_MOUNT_ARGS=""; \
		if [ -d "$(ANSIBLE_AWS_DIR)" ]; then \
			AWS_MOUNT_ARGS="-v $(ANSIBLE_AWS_DIR):/root/.aws:ro"; \
		fi; \
		docker run --rm \
			-e AWS_PROFILE \
			-e AWS_REGION="$(REGION)" \
			-e AWS_DEFAULT_REGION="$(REGION)" \
			-e AWS_ACCESS_KEY_ID \
			-e AWS_SECRET_ACCESS_KEY \
			-e AWS_SESSION_TOKEN \
			-e AWS_SDK_LOAD_CONFIG=1 \
			-e ANSIBLE_AWS_SSM_BUCKET="$$BUCKET_NAME" \
			-v "$(CURDIR)":/workspace \
			$$AWS_MOUNT_ARGS \
			-w /workspace/$(ANSIBLE_DIR) \
			"$(ANSIBLE_IMAGE)" \
			ansible-playbook -i inventory.aws_ec2.yml playbook.yml --limit $(ANSIBLE_LIMIT); \
	else \
		cd $(ANSIBLE_DIR) && ANSIBLE_AWS_SSM_BUCKET="$$BUCKET_NAME" ansible-playbook -i inventory.aws_ec2.yml playbook.yml --limit $(ANSIBLE_LIMIT); \
	fi

test: curl-test ## API 疎通確認を実行

curl-test: ## API Gateway -> Lambda -> Ollama の疎通確認
	@echo "🧪 Testing generate API for $(ENV)..."
	@URL=$$(terraform output -raw generate_url) && \
	SECRET_NAME=$$(terraform output -raw shared_api_secret_name) && \
	API_KEY=$$(aws secretsmanager get-secret-value --secret-id "$$SECRET_NAME" --region "$(REGION)" --query SecretString --output text) && \
	REQUEST_BODY=$$(python3 -c 'import json, sys; print(json.dumps({"prompt": sys.argv[1], "model": sys.argv[2]}, ensure_ascii=False))' "$(PROMPT)" "$(MODEL)") && \
	echo "POST $$URL" && \
	curl -sS -X POST "$$URL" \
		-H "content-type: application/json" \
		-H "x-api-key: $$API_KEY" \
		-d "$$REQUEST_BODY" | python3 -m json.tool

up: apply ansible curl-test ## 初期構築をまとめて実行
	@echo "✨ $(ENV) environment is ready."

down: destroy ## destroy の別名

clean: ## Terraform のローカル一時ファイルを削除
	@echo "🧹 Cleaning Terraform local files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup

.DEFAULT_GOAL := help
