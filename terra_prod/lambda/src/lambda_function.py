"""
シンプルなLambda関数のサンプル

このLambda関数は以下の機能を持つ:
1. イベントデータの受け取りと処理
2. 環境変数の読み取り
3. ログ出力
4. JSON形式のレスポンス返却
"""

import base64
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


def _extract_request_payload(event):
    """API Gateway / 直接Invoke の両方から入力データを取り出す。"""
    if not isinstance(event, dict):
        return {}, {}

    payload = {}
    request_meta = {
        'source': 'direct-invoke',
        'raw_path': event.get('rawPath'),
        'request_context': event.get('requestContext', {})
    }

    query_params = event.get('queryStringParameters') or {}
    if isinstance(query_params, dict):
        payload.update(query_params)

    body = event.get('body')
    if body:
        request_meta['source'] = 'api-gateway'
        if event.get('isBase64Encoded'):
            body = base64.b64decode(body).decode('utf-8')

        try:
            parsed_body = json.loads(body)
            if isinstance(parsed_body, dict):
                payload.update(parsed_body)
            else:
                payload['body'] = parsed_body
        except json.JSONDecodeError:
            payload['body'] = body
    elif 'requestContext' in event:
        request_meta['source'] = 'api-gateway'

    direct_fields = {
        key: value
        for key, value in event.items()
        if key not in {
            'version',
            'routeKey',
            'rawPath',
            'rawQueryString',
            'headers',
            'requestContext',
            'body',
            'isBase64Encoded',
            'queryStringParameters'
        }
    }
    payload.update(direct_fields)

    return payload, request_meta


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
    
    # API Gatewayや直接Invokeから入力を抽出
    request_payload, request_meta = _extract_request_payload(event)

    # 現在時刻を取得
    current_time = datetime.now().isoformat()
    
    # イベントからデータを抽出
    # eventは辞書型なので、.get()を使って安全にアクセス
    name = request_payload.get('name', 'World')
    message = request_payload.get('message', 'Hello')
    
    # レスポンスデータの作成
    response_data = {
        'timestamp': current_time,
        'environment': environment,
        'app_name': app_name,
        'request_id': context.aws_request_id,
        'greeting': f"{message}, {name}!",
        'input_event': request_payload,
        'request': request_meta,
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