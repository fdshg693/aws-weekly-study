# ECS Fargate + ALB デプロイ用 Makefile
# 使い方: make help

# ============================================================
# 設定
# ============================================================
ENV          ?= dev
IMAGE_TAG    ?= v3
AWS_REGION   ?= ap-northeast-1
TFVARS_FILE  := $(ENV).tfvars

# ============================================================
# ヘルプ
# ============================================================
.PHONY: help
help: ## コマンド一覧を表示
	@echo ""
	@echo "使い方: make <target> [ENV=dev|prod] [IMAGE_TAG=v1]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "デプロイ手順（初回）:"
	@echo "  1. make init"
	@echo "  2. make ecr-create"
	@echo "  3. make docker-push"
	@echo "  4. make deploy"
	@echo "  5. make status"
	@echo ""

# ============================================================
# Terraform 基本操作
# ============================================================
.PHONY: init
init: ## Terraform初期化
	terraform init

.PHONY: plan
plan: ## 変更内容のプレビュー
	terraform plan -var-file=$(TFVARS_FILE)

# ============================================================
# デプロイ手順
# ============================================================
.PHONY: ecr-create
ecr-create: ## Step1: ECRリポジトリを作成
	terraform apply -var-file=$(TFVARS_FILE) -target=aws_ecr_repository.main

.PHONY: docker-login
docker-login: ## ECRにDockerログイン
	@AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text) && \
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $$AWS_ACCOUNT_ID.dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: docker-build
docker-build: ## Dockerイメージをビルド（linux/amd64）
	docker build --platform linux/amd64 -t ecs-sample docker/

.PHONY: docker-push
docker-push: docker-login docker-build ## Step2: Dockerイメージをビルド&ECRにプッシュ
	@ECR_URI=$$(terraform output -raw ecr_repository_url) && \
	docker tag ecs-sample:latest $$ECR_URI:$(IMAGE_TAG) && \
	docker push $$ECR_URI:$(IMAGE_TAG) && \
	echo "" && \
	echo "プッシュ完了: $$ECR_URI:$(IMAGE_TAG)"

.PHONY: deploy
deploy: ## Step3: 全リソースをデプロイ
	@ECR_URI=$$(terraform output -raw ecr_repository_url) && \
	terraform apply -var-file=$(TFVARS_FILE) -var="container_image=$$ECR_URI:$(IMAGE_TAG)"

# ============================================================
# 確認・運用
# ============================================================
.PHONY: status
status: ## ALBのURLとECSサービスの状態を表示
	@echo "=== ALB URL ==="
	@terraform output alb_dns_name 2>/dev/null || echo "(未デプロイ)"
	@echo ""
	@echo "=== ECS サービス状態 ==="
	@CLUSTER=$$(terraform output -raw ecs_cluster_name 2>/dev/null) && \
	SERVICE=$$(terraform output -raw ecs_service_name 2>/dev/null) && \
	aws ecs describe-services \
		--cluster $$CLUSTER \
		--services $$SERVICE \
		--query 'services[0].{desiredCount:desiredCount,runningCount:runningCount,status:status}' \
		--output table \
	|| echo "(未デプロイ)"

.PHONY: logs
logs: ## ECSタスクのログを表示（直近50行）
	@LOG_GROUP=$$(terraform output -raw cloudwatch_log_group) && \
	aws logs tail $$LOG_GROUP --since 1h --format short | tail -50

.PHONY: curl
curl: ## ALBにcurlでアクセスして動作確認
	@ALB_DNS=$$(terraform output -raw alb_dns_name | sed 's|http://||') && \
	curl -s $$ALB_DNS

.PHONY: outputs
outputs: ## Terraformの全出力値を表示
	terraform output

# ============================================================
# 削除
# ============================================================
.PHONY: destroy
destroy: ## 全リソースを削除（NAT Gateway課金に注意!）
	@echo "WARNING: 全リソースを削除します（ENV=$(ENV)）"
	terraform destroy -var-file=$(TFVARS_FILE)

# ============================================================
# 再デプロイ（イメージ更新時）
# ============================================================
.PHONY: redeploy
redeploy: docker-push deploy ## イメージを再ビルド&プッシュして再デプロイ
