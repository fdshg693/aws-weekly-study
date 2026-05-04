#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "${PYTHON_BIN} が見つかりません。PYTHON_BIN を指定するか python3 をインストールしてください。" >&2
  exit 1
fi

exec "$PYTHON_BIN" "$SCRIPT_DIR/analyze_request_logs.py" "$@"
