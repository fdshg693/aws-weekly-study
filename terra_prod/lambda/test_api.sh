#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ENVIRONMENT="${1:-}"
REQUEST_NAME="${REQUEST_NAME:-API Gateway}"
REQUEST_MESSAGE="${REQUEST_MESSAGE:-Hello from test_api.sh}"
API_URL="${API_URL:-}"
API_GATEWAY_NAME="${API_GATEWAY_NAME:-}"
API_GATEWAY_STAGE_NAME="${API_GATEWAY_STAGE_NAME:-}"
AWS_REGION="${AWS_REGION:-}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform が見つかりません。Terraform をインストールしてから再実行してください。" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl が見つかりません。" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq が見つかりません。レスポンス整形のために必要です。" >&2
  exit 1
fi

terraform_output_raw() {
  local output_name="$1"
  terraform output -raw "$output_name" 2>/dev/null || true
}

terraform_output_json_field() {
  local output_name="$1"
  local jq_filter="$2"
  terraform output -json "$output_name" 2>/dev/null | jq -r "$jq_filter // empty" 2>/dev/null || true
}

if [[ -z "$API_URL" ]]; then
  API_URL="$(terraform_output_raw api_invoke_url)"
fi

if [[ -z "$API_URL" ]]; then
  echo "API URL を取得できませんでした。先に terraform apply を実行するか、API_URL 環境変数を指定してください。" >&2
  exit 1
fi

if [[ -z "$ENVIRONMENT" ]]; then
  ENVIRONMENT="$(terraform_output_json_field deployment_summary '.environment')"
fi

if [[ -z "$ENVIRONMENT" ]]; then
  ENVIRONMENT="$(terraform_output_json_field environment_variables '.ENVIRONMENT')"
fi

if [[ -z "$ENVIRONMENT" ]]; then
  ENVIRONMENT="unknown"
fi

if [[ -z "$API_GATEWAY_NAME" ]]; then
  API_GATEWAY_NAME="$(terraform_output_raw api_gateway_name)"
fi

if [[ -z "$API_GATEWAY_STAGE_NAME" ]]; then
  API_GATEWAY_STAGE_NAME="$(terraform_output_raw api_gateway_stage_name)"
fi

if [[ -z "$AWS_REGION" ]]; then
  AWS_REGION="$(terraform_output_json_field deployment_summary '.region')"
fi

POST_PAYLOAD="$(jq -cn --arg name "$REQUEST_NAME" --arg message "$REQUEST_MESSAGE" --arg environment "$ENVIRONMENT" '{name: $name, message: $message, environment: $environment}')"

echo "==> Testing API Gateway endpoint"
echo "Environment: $ENVIRONMENT"
if [[ -n "$AWS_REGION" ]]; then
  echo "Region: $AWS_REGION"
fi
if [[ -n "$API_GATEWAY_NAME" ]]; then
  echo "API Gateway: $API_GATEWAY_NAME"
fi
if [[ -n "$API_GATEWAY_STAGE_NAME" ]]; then
  echo "Stage: $API_GATEWAY_STAGE_NAME"
fi
echo "URL: $API_URL"
echo

echo "[1/2] POST request"
POST_RESPONSE="$(curl -sS -X POST "$API_URL" -H 'Content-Type: application/json' -d "$POST_PAYLOAD")"
echo "$POST_RESPONSE" | jq .

POST_GREETING="$(echo "$POST_RESPONSE" | jq -r '.greeting // empty')"
if [[ "$POST_GREETING" != "$REQUEST_MESSAGE, $REQUEST_NAME!" ]]; then
  echo "POST レスポンスの greeting が期待値と一致しません。" >&2
  exit 1
fi

echo
echo "[2/2] GET request"
GET_RESPONSE="$(curl -sS --get "$API_URL" --data-urlencode "name=$REQUEST_NAME" --data-urlencode "message=$REQUEST_MESSAGE")"
echo "$GET_RESPONSE" | jq .

GET_GREETING="$(echo "$GET_RESPONSE" | jq -r '.greeting // empty')"
if [[ "$GET_GREETING" != "$REQUEST_MESSAGE, $REQUEST_NAME!" ]]; then
  echo "GET レスポンスの greeting が期待値と一致しません。" >&2
  exit 1
fi

echo
echo "API テスト成功 🎉"