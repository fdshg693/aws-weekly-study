# ECS Fargate + FastMCP デプロイ補助 Makefile
# 使い方: make help

SHELL := /bin/sh

.DEFAULT_GOAL := help

ENV ?= dev
TFVARS_FILE := $(ENV).tfvars
AWS_REGION ?= us-east-1
IMAGE_NAME ?= ecs-mcp
IMAGE_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
PLATFORM ?= linux/amd64
SINCE ?= 30m

ifneq ($(strip $(DESIRED_COUNT)),)
DESIRED_COUNT_ARG := -var="desired_count=$(DESIRED_COUNT)"
else
DESIRED_COUNT_ARG :=
endif

.PHONY: help check-tools check-tfvars init fmt validate plan apply bootstrap destroy \
	outputs urls docker-login docker-build docker-push deploy release status logs health

help: ## コマンド一覧を表示
	@echo ""
	@echo "使い方: make <target> [ENV=dev|prod] [IMAGE_TAG=<tag>] [DESIRED_COUNT=<n>]"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "おすすめ手順（初回）:"
	@echo "  1. make bootstrap ENV=dev"
	@echo "  2. make docker-push ENV=dev"
	@echo "  3. make deploy ENV=dev DESIRED_COUNT=1"
	@echo ""
	@echo "おすすめ手順（更新時）:"
	@echo "  make release ENV=dev DESIRED_COUNT=1"
	@echo ""
	@echo "※ IMAGE_TAG は未指定なら Git の short SHA、無ければタイムスタンプを使います。"

check-tools: ## 必要コマンド(terraform/aws/docker)を確認
	@command -v terraform >/dev/null 2>&1 || { echo "❌ terraform が見つかりません"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "❌ aws CLI が見つかりません"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "❌ docker が見つかりません"; exit 1; }

check-tfvars: ## 指定環境の tfvars ファイル存在確認
	@test -f "$(TFVARS_FILE)" || { echo "❌ $(TFVARS_FILE) が見つかりません"; exit 1; }

init: check-tfvars ## Terraform を初期化
	terraform init

fmt: ## Terraform ファイルを整形
	terraform fmt -recursive

validate: init ## Terraform 設定を検証
	terraform validate

plan: init ## 現在の tfvars で plan を確認
	terraform plan -var-file="$(TFVARS_FILE)"

apply: init ## 現在の tfvars で apply を実行
	terraform apply -var-file="$(TFVARS_FILE)"

bootstrap: init ## 初回構築向けに desired_count=0 で基盤を作成
	terraform apply -var-file="$(TFVARS_FILE)" -var="desired_count=0"

destroy: init ## 現在の tfvars でリソースを削除
	@echo "⚠️  ENV=$(ENV) のリソースを削除します"
	terraform destroy -var-file="$(TFVARS_FILE)"

outputs: ## Terraform outputs を表示
	terraform output

urls: ## 公開 URL / ECR URL / OIDC callback URL を表示
	@echo "=== URLs ==="
	@terraform output -raw https_base_url 2>/dev/null | sed 's#^#Base URL: #' || echo "Base URL: (未作成)"
	@terraform output -raw mcp_url 2>/dev/null | sed 's#^#MCP URL:  #' || echo "MCP URL:  (未作成)"
	@terraform output -raw health_url 2>/dev/null | sed 's#^#Health:   #' || echo "Health:   (未作成)"
	@terraform output -raw oidc_redirect_uri 2>/dev/null | sed 's#^#OIDC CB:  #' || echo "OIDC CB:  (未作成)"
	@terraform output -raw ecr_repository_url 2>/dev/null | sed 's#^#ECR:      #' || echo "ECR:      (未作成)"

docker-login: check-tools ## ECR へ Docker ログイン
	@AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
	aws ecr get-login-password --region "$(AWS_REGION)" | \
		docker login --username AWS --password-stdin "$$AWS_ACCOUNT_ID.dkr.ecr.$(AWS_REGION).amazonaws.com"

docker-build: check-tools ## Docker イメージをビルド
	docker build --platform "$(PLATFORM)" -f docker/Dockerfile -t "$(IMAGE_NAME):$(IMAGE_TAG)" .

docker-push: docker-login docker-build ## Docker イメージを ECR に push
	@ECR_URI=$$(terraform output -raw ecr_repository_url 2>/dev/null) || { \
		echo "❌ ecr_repository_url を取得できません。先に 'make bootstrap ENV=$(ENV)' を実行してください。"; \
		exit 1; \
	}; \
	docker tag "$(IMAGE_NAME):$(IMAGE_TAG)" "$$ECR_URI:$(IMAGE_TAG)" && \
	docker push "$$ECR_URI:$(IMAGE_TAG)" && \
	echo "✅ Pushed: $$ECR_URI:$(IMAGE_TAG)"

deploy: init ## 指定 IMAGE_TAG のイメージで ECS を更新
	@ECR_URI=$$(terraform output -raw ecr_repository_url 2>/dev/null) || { \
		echo "❌ ecr_repository_url を取得できません。先に 'make bootstrap ENV=$(ENV)' を実行してください。"; \
		exit 1; \
	}; \
	echo "🚀 Deploying $$ECR_URI:$(IMAGE_TAG)"; \
	terraform apply -var-file="$(TFVARS_FILE)" -var="container_image=$$ECR_URI:$(IMAGE_TAG)" $(DESIRED_COUNT_ARG)

release: docker-push deploy ## build → push → deploy を一気に実行

status: ## ECS サービス状態を表示
	@echo "=== Terraform outputs ==="
	@terraform output 2>/dev/null || echo "(まだ apply 前です)"
	@echo ""
	@echo "=== ECS service ==="
	@CLUSTER=$$(terraform output -raw ecs_cluster_name 2>/dev/null) && \
	SERVICE=$$(terraform output -raw ecs_service_name 2>/dev/null) && \
	aws ecs describe-services \
		--region "$(AWS_REGION)" \
		--cluster "$$CLUSTER" \
		--services "$$SERVICE" \
		--query 'services[0].{status:status,desiredCount:desiredCount,runningCount:runningCount,pendingCount:pendingCount}' \
		--output table \
	|| echo "(まだ ECS Service が作成されていません)"

logs: ## CloudWatch Logs を表示（SINCE=30m など変更可）
	@LOG_GROUP=$$(terraform output -raw cloudwatch_log_group 2>/dev/null) || { \
		echo "❌ cloudwatch_log_group を取得できません。先に apply を実行してください。"; \
		exit 1; \
	}; \
	aws logs tail "$$LOG_GROUP" --region "$(AWS_REGION)" --since "$(SINCE)" --format short

health: ## /health へ疎通確認
	@HEALTH_URL=$$(terraform output -raw health_url 2>/dev/null) || { \
		echo "❌ health_url を取得できません。先に apply を実行してください。"; \
		exit 1; \
	}; \
	echo "🏥 $$HEALTH_URL"; \
	curl -fsSL "$$HEALTH_URL"