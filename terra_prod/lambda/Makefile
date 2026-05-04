ENV ?= dev
API_URL ?=
API_KEY ?=
PROMPT ?= 2 + 3
METHOD ?= POST
SINCE ?= 1h
STAGE_COUNT ?= 3
STAGE_DURATION ?= 30s
# 8080が使用中の場合は、別のポートを指定して `make demo-app-up` を実行してください。
# CORSで許可しているポートにする必要があります。
DEMO_APP_PORT ?= 8080

DEMO_APP_DIR := $(CURDIR)/demo-app
DEMO_APP_NGINX_DIR := $(DEMO_APP_DIR)/nginx
DEMO_APP_NGINX_PREFIX := $(DEMO_APP_DIR)/.nginx
DEMO_APP_NGINX_TEMPLATE := $(DEMO_APP_NGINX_DIR)/nginx.conf.template
DEMO_APP_NGINX_CONF := $(DEMO_APP_NGINX_PREFIX)/nginx.conf
DEMO_APP_NGINX_PID := $(DEMO_APP_NGINX_PREFIX)/nginx.pid

TFVARS_dev := dev.tfvars
TFVARS_prod := prod.tfvars
TFVARS := $(TFVARS_$(ENV))

.PHONY: check-env help init fmt validate plan apply destroy output get-api-key rotate-secret test load-test analyze-request-logs demo-app-up demo-app-down

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
	@echo "  analyze-request-logs Aggregate Lambda request/error logs from CloudWatch Logs"
	@echo "  demo-app-up   Serve demo-app via local nginx on http://localhost:8080"
	@echo "  demo-app-down Stop the local demo-app nginx process"
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
	@echo ""
	@echo "analyze-request-logs options:"
	@echo "  START_TIME=<iso8601>  Start time, e.g. 2026-05-05T00:00:00Z"
	@echo "  END_TIME=<iso8601>    End time, default: now"
	@echo "  SINCE=<relative>      Relative window if START_TIME is omitted, e.g. 15m, 1h (default: $(SINCE))"
	@echo "  METHOD=POST|GET|ALL   Filter by HTTP method (default: $(METHOD))"
	@echo "  LOG_GROUP_NAME=<name> Override terraform output log_group_name"
	@echo "  AWS_REGION=<region>   Override terraform output deployment_summary.region"
	@echo "  DEMO_APP_PORT=<port>  Local nginx port for demo-app (default: $(DEMO_APP_PORT))"

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

analyze-request-logs:
	@START_TIME="$(START_TIME)" END_TIME="$(END_TIME)" SINCE="$(SINCE)" METHOD="$(METHOD)" LOG_GROUP_NAME="$(LOG_GROUP_NAME)" AWS_REGION="$(AWS_REGION)" \
		bash ./analyze_request_logs.sh

demo-app-up:
	@if ! command -v nginx >/dev/null 2>&1; then \
		echo "nginx が見つかりません。macOS なら 'brew install nginx' を実行してください。"; \
		exit 1; \
	fi
	@mkdir -p "$(DEMO_APP_NGINX_PREFIX)/logs"
	@sed "s/__DEMO_APP_PORT__/$(DEMO_APP_PORT)/g" "$(DEMO_APP_NGINX_TEMPLATE)" > "$(DEMO_APP_NGINX_CONF)"
	@nginx -t -p "$(DEMO_APP_NGINX_PREFIX)" -c "$(DEMO_APP_NGINX_CONF)"
	@if [ -f "$(DEMO_APP_NGINX_PID)" ] && kill -0 "$$(cat "$(DEMO_APP_NGINX_PID)")" 2>/dev/null; then \
		echo "demo-app nginx は既に起動しています。設定を reload します。"; \
		nginx -p "$(DEMO_APP_NGINX_PREFIX)" -c "$(DEMO_APP_NGINX_CONF)" -s reload; \
	else \
		echo "demo-app nginx を http://localhost:$(DEMO_APP_PORT) で起動します。"; \
		nginx -p "$(DEMO_APP_NGINX_PREFIX)" -c "$(DEMO_APP_NGINX_CONF)"; \
	fi

demo-app-down:
	@if ! command -v nginx >/dev/null 2>&1; then \
		echo "nginx が見つかりません。"; \
		exit 1; \
	fi
	@if [ -f "$(DEMO_APP_NGINX_TEMPLATE)" ]; then \
		sed "s/__DEMO_APP_PORT__/$(DEMO_APP_PORT)/g" "$(DEMO_APP_NGINX_TEMPLATE)" > "$(DEMO_APP_NGINX_CONF)"; \
	fi
	@if [ -f "$(DEMO_APP_NGINX_PID)" ] && kill -0 "$$(cat "$(DEMO_APP_NGINX_PID)")" 2>/dev/null; then \
		echo "demo-app nginx を停止します。"; \
		nginx -p "$(DEMO_APP_NGINX_PREFIX)" -c "$(DEMO_APP_NGINX_CONF)" -s stop; \
	else \
		echo "demo-app nginx は起動していません。"; \
	fi