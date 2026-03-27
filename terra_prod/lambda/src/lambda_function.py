"""
シンプルなLambda関数のサンプル

このLambda関数は以下の機能を持つ:
1. イベントデータの受け取りと処理
2. 環境変数の読み取り
3. ログ出力
4. JSON形式のレスポンス返却
"""

import json
import os
from datetime import datetime
import logging
import sys

# シェルスクリプト側から呼び出すローカルテストにおいて、PRINTなどでSTDINが混じると、パースが失敗するため、
# ログはstderrに出力するように設定する。
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(levelname)s] %(message)s',
    stream=sys.stderr  # ← これを追加
)

logger = logging.getLogger(__name__)


def lambda_handler(event, context):
    """
    Lambda関数のメインハンドラー
    
    Args:
        event (dict): Lambda関数に渡されるイベントデータ
            - API Gatewayからの場合: リクエスト情報を含む
            - S3イベントからの場合: バケット・オブジェクト情報を含む
            - 直接実行の場合: カスタムJSONデータ
        
        context (LambdaContext): Lambda実行コンテキスト
            - function_name: 関数名
            - function_version: バージョン
            - invoked_function_arn: ARN
            - memory_limit_in_mb: メモリ制限
            - aws_request_id: リクエストID
            - log_group_name: ログ群名
            - log_stream_name: ログストリーム名
    
    Returns:
        dict: レスポンスオブジェクト
            - statusCode: HTTPステータスコード
            - body: JSON文字列化されたレスポンスボディ
    """
    
    # 環境変数の読み取り
    # Terraformから設定される環境変数を取得
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    app_name = os.environ.get('APP_NAME', 'lambda-function')
    
    # ログ出力（CloudWatch Logsに記録される）
    logger.info(f"[INFO] Lambda function invoked in {environment} environment")
    logger.info(f"[INFO] Application: {app_name}")
    logger.info(f"[INFO] Request ID: {context.aws_request_id}")
    logger.info(f"[INFO] Function Name: {context.function_name}")
    logger.info(f"[INFO] Memory Limit: {context.memory_limit_in_mb} MB")
    
    # イベントの内容をログに出力（デバッグ用）
    logger.info(f"[DEBUG] Received event: {json.dumps(event)}")
    
    # 現在時刻を取得
    current_time = datetime.now().isoformat()
    
    # イベントからデータを抽出
    # eventは辞書型なので、.get()を使って安全にアクセス
    name = event.get('name', 'World')
    message = event.get('message', 'Hello')
    
    # レスポンスデータの作成
    response_data = {
        'timestamp': current_time,
        'environment': environment,
        'app_name': app_name,
        'request_id': context.aws_request_id,
        'greeting': f"{message}, {name}!",
        'input_event': event,
        'function_info': {
            'name': context.function_name,
            'version': context.function_version,
            'memory_mb': context.memory_limit_in_mb,
            'remaining_time_ms': context.get_remaining_time_in_millis()
        }
    }
    
    logger.info(f"[INFO] Response prepared successfully")
    
    # API Gatewayとの統合を想定したレスポンス形式
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            # CORS設定（必要に応じて変更）
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        },
        'body': json.dumps(response_data, ensure_ascii=False)
    }


def validate_event(event):
    """
    イベントデータのバリデーション例
    
    実際のユースケースに応じて、必要なフィールドの存在確認や
    データ型のチェックなどを実装できる
    
    Args:
        event (dict): 検証するイベントデータ
    
    Returns:
        tuple: (is_valid, error_message)
    
    Example:
        is_valid, error = validate_event(event)
        if not is_valid:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': error})
            }
    """
    if not isinstance(event, dict):
        return False, "Event must be a dictionary"
    
    return True, None


def process_data(data):
    """
    データ処理のロジック例
    
    実際のビジネスロジックをここに実装する
    - データベースへのクエリ
    - 外部APIの呼び出し
    - データ変換・集計
    - ファイル処理
    
    Args:
        data (dict): 処理するデータ
    
    Returns:
        dict: 処理結果
    """
    # サンプル処理: 文字列の大文字変換
    processed_data = {
        'original': data,
        'processed': str(data).upper()
    }
    
    return processed_data
