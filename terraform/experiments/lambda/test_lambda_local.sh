#!/usr/bin/env bash

################################################################################
# Lambda関数ローカルテストスクリプト
#
# このスクリプトは、Lambda関数をローカル環境でテストするためのものです。
# AWS CLIやPythonを使用して、実際のAWS環境にデプロイする前に
# Lambda関数の動作を確認できます。
#
# 必要な依存関係:
# - Python 3.9以上
# - AWS CLI（オプション：デプロイ後のテストに使用）
# - jq（オプション：JSON整形に使用）
#
# 使い方:
#   ./test_lambda_local.sh              # 対話モードで実行
#   ./test_lambda_local.sh --quick      # 基本テストのみ実行
#   ./test_lambda_local.sh --deploy     # デプロイ後のテストも実行
################################################################################

set -euo pipefail

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
LAMBDA_FUNCTION="lambda_function"
HANDLER_FUNCTION="lambda_handler"

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# ヘルパー関数
################################################################################

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# セパレーター表示
print_separator() {
    echo "================================================================================"
}

# JSON整形出力（jqがあれば使用、なければそのまま出力）
pretty_json() {
    if command -v jq &> /dev/null; then
        echo "$1" | jq '.'
    else
        echo "$1"
    fi
}

################################################################################
# 環境チェック
################################################################################

check_dependencies() {
    log_info "依存関係のチェック中..."
    
    # Pythonのチェック
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 が見つかりません。インストールしてください。"
        exit 1
    fi
    
    local python_version=$(python3 --version | awk '{print $2}')
    log_success "Python $python_version を検出"
    
    # AWS CLIのチェック（オプション）
    if command -v aws &> /dev/null; then
        local aws_version=$(aws --version 2>&1 | awk '{print $1}')
        log_success "$aws_version を検出"
    else
        log_warning "AWS CLI が見つかりません（デプロイ後のテストには必要）"
    fi
    
    # jqのチェック（オプション）
    if command -v jq &> /dev/null; then
        log_success "jq を検出（JSON整形が有効）"
    else
        log_warning "jq が見つかりません（JSON整形なしで出力）"
    fi
    
    # ソースディレクトリのチェック
    if [ ! -d "$SRC_DIR" ]; then
        log_error "ソースディレクトリが見つかりません: $SRC_DIR"
        exit 1
    fi
    
    # Lambda関数ファイルのチェック
    if [ ! -f "$SRC_DIR/${LAMBDA_FUNCTION}.py" ]; then
        log_error "Lambda関数が見つかりません: $SRC_DIR/${LAMBDA_FUNCTION}.py"
        exit 1
    fi
    
    log_success "すべての必須依存関係が確認されました"
    echo ""
}

################################################################################
# ローカルテスト実行
################################################################################

# Lambda関数のローカル実行
run_local_test() {
    local test_name="$1"
    local event_json="$2"
    
    print_separator
    log_info "テスト実行: $test_name"
    print_separator
    
    # テストイベントの表示
    log_info "テストイベント:"
    pretty_json "$event_json"
    echo ""
    
    # Lambda関数を実行
    log_info "Lambda関数を実行中..."
    
    # Pythonスクリプトでラップして実行
    local result=$(python3 <<EOF
import sys
import json
import os
from datetime import datetime

# ソースディレクトリをパスに追加
sys.path.insert(0, '${SRC_DIR}')

# 環境変数の設定（テスト用）
os.environ['ENVIRONMENT'] = 'test'
os.environ['APP_NAME'] = 'lambda-local-test'
os.environ['LOG_LEVEL'] = 'DEBUG'

# Lambda関数をインポート
from ${LAMBDA_FUNCTION} import ${HANDLER_FUNCTION}

# モックコンテキストクラス
class MockContext:
    def __init__(self):
        self.function_name = '${test_name}'
        self.function_version = '\$LATEST'
        self.invoked_function_arn = 'arn:aws:lambda:local:123456789012:function:local-test'
        self.memory_limit_in_mb = 128
        self.aws_request_id = 'local-test-request-id-' + datetime.now().strftime('%Y%m%d%H%M%S')
        self.log_group_name = '/aws/lambda/local-test'
        self.log_stream_name = 'local-test-stream'
    
    def get_remaining_time_in_millis(self):
        return 300000  # 5分

# テストイベント
event = json.loads('''${event_json}''')

# Lambda関数を実行
context = MockContext()
try:
    response = ${HANDLER_FUNCTION}(event, context)
    print(json.dumps(response, ensure_ascii=False, indent=2))
except Exception as e:
    print(json.dumps({
        'error': str(e),
        'type': type(e).__name__
    }, indent=2))
    sys.exit(1)
EOF
)
    
    # 実行結果のチェック
    if [ $? -eq 0 ]; then
        log_success "Lambda関数の実行に成功しました"
        echo ""
        log_info "レスポンス:"
        echo "$result"
        pretty_json "$result"
        echo ""
        
        # レスポンスの検証
        local status_code=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('statusCode', 0))")
        if [ "$status_code" = "200" ]; then
            log_success "ステータスコード: $status_code (正常)"
        else
            log_warning "ステータスコード: $status_code"
        fi
    else
        log_error "Lambda関数の実行に失敗しました"
        echo "$result"
        return 1
    fi
    
    echo ""
}

################################################################################
# テストケース定義
################################################################################

run_basic_tests() {
    log_info "基本テストを開始します..."
    echo ""
    
    # テスト1: シンプルなHello World
    run_local_test "シンプルなHello World" '{
        "name": "World",
        "message": "Hello"
    }'
    
    # テスト2: カスタムメッセージ
    run_local_test "カスタムメッセージ" '{
        "name": "太郎",
        "message": "こんにちは"
    }'
    
    # テスト3: 空のイベント
    run_local_test "空のイベント" '{}'
    
    # テスト4: 追加データを含むイベント
    run_local_test "追加データを含むイベント" '{
        "name": "Alice",
        "message": "Greetings",
        "extra_data": {
            "user_id": 12345,
            "timestamp": "2024-01-01T00:00:00Z"
        }
    }'
}

run_advanced_tests() {
    log_info "高度なテストを開始します..."
    echo ""
    
    # テスト5: 大きなペイロード
    run_local_test "大きなペイロード" '{
        "name": "Test User",
        "message": "Testing large payload",
        "data": {
            "items": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "metadata": {
                "created_at": "2024-01-01",
                "updated_at": "2024-01-02"
            }
        }
    }'
    
    # テスト6: 特殊文字を含むデータ
    run_local_test "特殊文字を含むデータ" '{
        "name": "テストユーザー",
        "message": "日本語メッセージ 🎉",
        "special_chars": "!@#$%^&*()"
    }'
}

################################################################################
# デプロイ後のテスト（AWS CLI使用）
################################################################################

run_deployed_tests() {
    log_info "デプロイされたLambda関数のテストを開始します..."
    echo ""
    
    # AWS CLIのチェック
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI が見つかりません"
        return 1
    fi
    
    # Lambda関数名の入力
    read -p "Lambda関数名を入力してください: " function_name
    
    if [ -z "$function_name" ]; then
        log_error "関数名が入力されませんでした"
        return 1
    fi
    
    # テストペイロード
    local test_payload='{"name":"AWS Lambda","message":"Hello from deployed function"}'
    
    print_separator
    log_info "AWS Lambda関数を呼び出し中: $function_name"
    print_separator
    
    # 一時ファイル
    local response_file=$(mktemp)
    
    # Lambda関数を呼び出し
    if aws lambda invoke \
        --function-name "$function_name" \
        --cli-binary-format raw-in-base64-out \
        --payload "$test_payload" \
        "$response_file" > /dev/null 2>&1; then
        
        log_success "Lambda関数の呼び出しに成功しました"
        echo ""
        log_info "レスポンス:"
        pretty_json "$(cat "$response_file")"
        echo ""
    else
        log_error "Lambda関数の呼び出しに失敗しました"
        cat "$response_file"
    fi
    
    # 一時ファイルのクリーンアップ
    rm -f "$response_file"
}

################################################################################
# メイン処理
################################################################################

main() {
    print_separator
    echo "Lambda関数ローカルテストスクリプト"
    print_separator
    echo ""
    
    # 依存関係のチェック
    check_dependencies
    
    # コマンドライン引数の処理
    local mode="interactive"
    
    case "${1:-}" in
        --quick)
            mode="quick"
            ;;
        --deploy)
            mode="deploy"
            ;;
        --all)
            mode="all"
            ;;
        --help|-h)
            echo "使い方: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --quick    基本テストのみ実行"
            echo "  --deploy   デプロイ後のテストを実行"
            echo "  --all      すべてのテストを実行"
            echo "  --help     このヘルプを表示"
            exit 0
            ;;
    esac
    
    # テストの実行
    case "$mode" in
        quick)
            run_basic_tests
            ;;
        deploy)
            run_deployed_tests
            ;;
        all)
            run_basic_tests
            run_advanced_tests
            run_deployed_tests
            ;;
        interactive)
            # 対話モード
            echo "テストモードを選択してください:"
            echo "1) 基本テストのみ"
            echo "2) すべてのローカルテスト"
            echo "3) デプロイ後のテスト"
            echo "4) すべて"
            read -p "選択 [1-4]: " choice
            
            case "$choice" in
                1)
                    run_basic_tests
                    ;;
                2)
                    run_basic_tests
                    run_advanced_tests
                    ;;
                3)
                    run_deployed_tests
                    ;;
                4)
                    run_basic_tests
                    run_advanced_tests
                    run_deployed_tests
                    ;;
                *)
                    log_error "無効な選択です"
                    exit 1
                    ;;
            esac
            ;;
    esac
    
    print_separator
    log_success "すべてのテストが完了しました！"
    print_separator
}

# スクリプト実行
main "$@"
