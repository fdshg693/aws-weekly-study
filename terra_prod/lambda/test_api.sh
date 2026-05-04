#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ENVIRONMENT="${1:-}"
PROMPT="${PROMPT:-AWS Lambda と Amazon Bedrock の関係を一文で説明してください}"
API_URL="${API_URL:-}"
API_KEY="${API_KEY:-}"
API_GATEWAY_NAME="${API_GATEWAY_NAME:-}"
API_GATEWAY_STAGE_NAME="${API_GATEWAY_STAGE_NAME:-}"
AWS_REGION="${AWS_REGION:-}"
MODEL_ID="${MODEL_ID:-}"

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

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI が見つかりません。Secrets Manager から API キーを取得するために必要です。" >&2
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

if [[ -z "$MODEL_ID" ]]; then
  MODEL_ID="$(terraform_output_json_field deployment_summary '.bedrock_model_id')"
fi

if [[ -z "$API_KEY" ]]; then
  SECRET_NAME="$(terraform_output_raw api_key_secret_name)"
  if [[ -z "$SECRET_NAME" ]]; then
    echo "API key secret name を取得できませんでした。terraform apply 実行後に再試行してください。" >&2
    exit 1
  fi

  API_KEY="$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text | jq -r '.api_key // .')"
fi

if [[ -z "$API_KEY" ]]; then
  echo "API key を取得できませんでした。" >&2
  exit 1
fi

POST_PAYLOAD="$(jq -cn --arg prompt "$PROMPT" --arg environment "$ENVIRONMENT" '{prompt: $prompt, environment: $environment}')"

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
echo "Model: ${MODEL_ID:-unknown}"
echo

echo "[1/4] Unauthenticated GET should be rejected"
UNAUTH_BODY_FILE="$(mktemp)"
UNAUTH_STATUS="$(curl -sS -o "$UNAUTH_BODY_FILE" -w '%{http_code}' "$API_URL")"
cat "$UNAUTH_BODY_FILE" | jq . 2>/dev/null || cat "$UNAUTH_BODY_FILE"
if [[ "$UNAUTH_STATUS" != "401" && "$UNAUTH_STATUS" != "403" ]]; then
  echo "認証なしリクエストが拒否されませんでした。status=$UNAUTH_STATUS" >&2
  rm -f "$UNAUTH_BODY_FILE"
  exit 1
fi
rm -f "$UNAUTH_BODY_FILE"

echo
echo "[2/4] Invalid API key should be rejected"
INVALID_BODY_FILE="$(mktemp)"
INVALID_STATUS="$(curl -sS -o "$INVALID_BODY_FILE" -w '%{http_code}' -H 'x-api-key: invalid-key' "$API_URL")"
cat "$INVALID_BODY_FILE" | jq . 2>/dev/null || cat "$INVALID_BODY_FILE"
if [[ "$INVALID_STATUS" != "401" && "$INVALID_STATUS" != "403" ]]; then
  echo "不正 API キーのリクエストが拒否されませんでした。status=$INVALID_STATUS" >&2
  rm -f "$INVALID_BODY_FILE"
  exit 1
fi
rm -f "$INVALID_BODY_FILE"

echo
echo "[3/4] Authenticated GET health check"
GET_RESPONSE="$(curl -sS --get "$API_URL" -H "x-api-key: $API_KEY")"
echo "$GET_RESPONSE" | jq .

GET_STATUS_VALUE="$(echo "$GET_RESPONSE" | jq -r '.status // empty')"
if [[ "$GET_STATUS_VALUE" != "ok" ]]; then
  echo "GET レスポンスの status が期待値と一致しません。" >&2
  exit 1
fi

GET_MODEL_ID="$(echo "$GET_RESPONSE" | jq -r '.model_id // empty')"
if [[ -n "$MODEL_ID" && "$GET_MODEL_ID" != "$MODEL_ID" ]]; then
  echo "GET レスポンスの model_id が期待値と一致しません。" >&2
  exit 1
fi

echo
echo "[4/4] Authenticated POST Bedrock invocation"
POST_RESPONSE="$(curl -sS -X POST "$API_URL" -H 'Content-Type: application/json' -H "x-api-key: $API_KEY" -d "$POST_PAYLOAD")"
echo "$POST_RESPONSE" | jq .

POST_OUTPUT_TEXT="$(echo "$POST_RESPONSE" | jq -r '.output_text // empty')"
if [[ -z "$POST_OUTPUT_TEXT" ]]; then
  echo "POST レスポンスに output_text が含まれていません。" >&2
  exit 1
fi

POST_MODEL_ID="$(echo "$POST_RESPONSE" | jq -r '.model_id // empty')"
if [[ -n "$MODEL_ID" && "$POST_MODEL_ID" != "$MODEL_ID" ]]; then
  echo "POST レスポンスの model_id が期待値と一致しません。" >&2
  exit 1
fi

echo
echo "API テスト成功 🎉"