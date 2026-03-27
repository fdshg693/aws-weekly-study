#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ENVIRONMENT="${1:-dev}"
REQUEST_NAME="${REQUEST_NAME:-API Gateway}"
REQUEST_MESSAGE="${REQUEST_MESSAGE:-Hello from test_api.sh}"
API_URL="${API_URL:-}"

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

if [[ -z "$API_URL" ]]; then
  API_URL="$(terraform output -raw api_invoke_url 2>/dev/null || true)"
fi

if [[ -z "$API_URL" ]]; then
  echo "API URL を取得できませんでした。先に terraform apply を実行するか、API_URL 環境変数を指定してください。" >&2
  exit 1
fi

POST_PAYLOAD="$(jq -cn --arg name "$REQUEST_NAME" --arg message "$REQUEST_MESSAGE" --arg environment "$ENVIRONMENT" '{name: $name, message: $message, environment: $environment}')"

echo "==> Testing API Gateway endpoint"
echo "Environment: $ENVIRONMENT"
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