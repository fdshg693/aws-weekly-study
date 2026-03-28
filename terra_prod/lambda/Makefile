ENV ?= dev
API_URL ?=
REQUEST_NAME ?= k6
REQUEST_MESSAGE ?= Hello from k6

TFVARS_dev := dev.tfvars
TFVARS_prod := prod.tfvars
TFVARS := $(TFVARS_$(ENV))

.PHONY: check-env help init fmt validate plan apply destroy output test load-test

check-env:
	@if [ -z "$(TFVARS)" ]; then \
		echo "ENV must be dev or prod"; \
		exit 1; \
	fi

help:
	@echo "Usage: make <target> ENV=dev|prod"
	@echo ""
	@echo "Targets:"
	@echo "  init      Terraform init"
	@echo "  fmt       Terraform fmt -recursive"
	@echo "  validate  Terraform validate"
	@echo "  plan      Terraform plan with environment tfvars"
	@echo "  apply     Terraform apply with environment tfvars"
	@echo "  destroy   Terraform destroy with environment tfvars"
	@echo "  output    Show Terraform outputs"
	@echo "  test      Test deployed API Gateway endpoint"
	@echo "  load-test Run k6 load test for GET/POST API Gateway endpoint and save logs"

init: check-env
	terraform init

fmt:
	terraform fmt -recursive

validate: check-env fmt
	terraform validate

plan: check-env
	terraform plan -var-file=$(TFVARS)

apply: check-env
	terraform apply -var-file=$(TFVARS)

destroy: check-env
	terraform destroy -var-file=$(TFVARS)

output:
	terraform output

test: check-env
	./test_api.sh $(ENV)

load-test: check-env
	@API_URL_VALUE="$(API_URL)"; \
	TIMESTAMP="$$(date +%Y%m%d-%H%M%S)"; \
	LOG_DIR="./logs"; \
	STDOUT_LOG="$$LOG_DIR/k6-load-test-$$TIMESTAMP.log"; \
	SUMMARY_JSON="$$LOG_DIR/k6-load-test-$$TIMESTAMP-summary.json"; \
	if [ -z "$$API_URL_VALUE" ]; then \
		API_URL_VALUE="$$(terraform output -raw api_invoke_url 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$API_URL_VALUE" ]; then \
		echo "API URL を取得できませんでした。terraform apply 実行後に再試行するか、API_URL=<url> を指定してください。"; \
		exit 1; \
	fi; \
	mkdir -p "$$LOG_DIR"; \
	echo "Saving k6 stdout log to: $$STDOUT_LOG"; \
	echo "Saving k6 summary JSON to: $$SUMMARY_JSON"; \
	API_URL="$$API_URL_VALUE" REQUEST_NAME="$(REQUEST_NAME)" REQUEST_MESSAGE="$(REQUEST_MESSAGE)" \
	k6 run --summary-export "$$SUMMARY_JSON" ./k6_api_test.js 2>&1 | tee "$$STDOUT_LOG"