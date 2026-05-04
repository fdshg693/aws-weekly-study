ENV ?= dev
API_URL ?=
API_KEY ?=
PROMPT ?= 2 + 3
STAGE_COUNT ?= 3
STAGE_DURATION ?= 30s

TFVARS_dev := dev.tfvars
TFVARS_prod := prod.tfvars
TFVARS := $(TFVARS_$(ENV))

.PHONY: check-env help init fmt validate plan apply destroy output get-api-key rotate-secret test load-test

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
	@echo "  get-api-key Fetch the current API key from Secrets Manager"
	@echo "  rotate-secret Trigger immediate API key rotation"
	@echo "  test      Test deployed API Gateway endpoint"
	@echo "  load-test Run k6 load test for GET/POST API Gateway endpoint and save logs"
	@echo ""
	@echo "test options:"
	@echo "  PROMPT=<text>         Prompt sent to Bedrock during POST test"
	@echo "  API_URL=<url>         Override terraform output api_invoke_url"
	@echo "  API_KEY=<key>         Override Secrets Manager lookup result"
	@echo ""
	@echo "load-test options:"
	@echo "  STAGE_COUNT=<n>       Number of load stages (default: $(STAGE_COUNT))"
	@echo "  STAGE_DURATION=<dur>  Duration per stage, e.g. 10s, 1m (default: $(STAGE_DURATION))"
	@echo "  PROMPT=<text>         Prompt template sent in POST requests"
	@echo "  THROTTLED_RATE_THRESHOLD=<rate>         Allowed 429 ratio (default: k6 script default)"
	@echo "  UNEXPECTED_FAILURE_RATE_THRESHOLD=<rate> Allowed unexpected failure ratio (default: k6 script default)"
	@echo "  LOG_THROTTLED_RESPONSES=true            Sample a few 429 warnings in k6 output"
	@echo "  API_URL=<url>         Override terraform output api_invoke_url"
	@echo "  API_KEY=<key>         Override Secrets Manager lookup result"

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

get-api-key: check-env
	@SECRET_NAME="$$(terraform output -raw api_key_secret_name 2>/dev/null || true)"; \
	if [ -z "$$SECRET_NAME" ]; then \
		echo "API key secret name を取得できませんでした。terraform apply 実行後に再試行してください。"; \
		exit 1; \
	fi; \
	aws secretsmanager get-secret-value \
	  --secret-id "$$SECRET_NAME" \
	  --query SecretString \
	  --output text | jq -r '.api_key // .'

rotate-secret: check-env
	@SECRET_NAME="$$(terraform output -raw api_key_secret_name 2>/dev/null || true)"; \
	if [ -z "$$SECRET_NAME" ]; then \
		echo "API key secret name を取得できませんでした。terraform apply 実行後に再試行してください。"; \
		exit 1; \
	fi; \
	aws secretsmanager rotate-secret --secret-id "$$SECRET_NAME" --rotate-immediately

test: check-env
	PROMPT="$(PROMPT)" API_URL="$(API_URL)" API_KEY="$(API_KEY)" ./test_api.sh $(ENV)

load-test: check-env
	@API_URL_VALUE="$(API_URL)"; \
	API_KEY_VALUE="$(API_KEY)"; \
	SECRET_NAME=""; \
	TIMESTAMP="$$(date +%Y%m%d-%H%M%S)"; \
	LOG_DIR="./logs"; \
	STDOUT_LOG="$$LOG_DIR/k6-load-test-$$TIMESTAMP.log"; \
	SUMMARY_JSON="$$LOG_DIR/k6-load-test-$$TIMESTAMP-summary.json"; \
	if [ -z "$$API_URL_VALUE" ]; then \
		API_URL_VALUE="$$(terraform output -raw api_invoke_url 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$API_KEY_VALUE" ]; then \
		SECRET_NAME="$$(terraform output -raw api_key_secret_name 2>/dev/null || true)"; \
		if [ -n "$$SECRET_NAME" ]; then \
			API_KEY_VALUE="$$(aws secretsmanager get-secret-value --secret-id "$$SECRET_NAME" --query SecretString --output text 2>/dev/null | jq -r '.api_key // .' 2>/dev/null || true)"; \
		fi; \
	fi; \
	if [ -z "$$API_URL_VALUE" ]; then \
		echo "API URL を取得できませんでした。terraform apply 実行後に再試行するか、API_URL=<url> を指定してください。"; \
		exit 1; \
	fi; \
	if [ -z "$$API_KEY_VALUE" ]; then \
		echo "API key を取得できませんでした。terraform apply 実行後に再試行するか、API_KEY=<key> を指定してください。"; \
		exit 1; \
	fi; \
	mkdir -p "$$LOG_DIR"; \
	echo "Saving k6 stdout log to: $$STDOUT_LOG"; \
	echo "Saving k6 summary JSON to: $$SUMMARY_JSON"; \
	echo "Running load test with STAGE_COUNT=$(STAGE_COUNT), STAGE_DURATION=$(STAGE_DURATION)"; \
	API_URL="$$API_URL_VALUE" API_KEY="$$API_KEY_VALUE" PROMPT="$(PROMPT)" STAGE_COUNT="$(STAGE_COUNT)" STAGE_DURATION="$(STAGE_DURATION)" THROTTLED_RATE_THRESHOLD="$(THROTTLED_RATE_THRESHOLD)" UNEXPECTED_FAILURE_RATE_THRESHOLD="$(UNEXPECTED_FAILURE_RATE_THRESHOLD)" LOG_THROTTLED_RESPONSES="$(LOG_THROTTLED_RESPONSES)" \
	k6 run --summary-export "$$SUMMARY_JSON" ./k6_api_test.js 2>&1 | tee "$$STDOUT_LOG"