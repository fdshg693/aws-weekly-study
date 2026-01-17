"""
Producer Lambda 関数
=====================
API Gateway からのリクエストを受け取り、SQS キューに注文メッセージを送信する

【Lambda ベストプラクティス】
1. ハンドラー外でクライアントを初期化する（コールドスタート最適化）
   - Lambda コンテナは再利用されるため、初期化コードは一度だけ実行される
   - boto3 クライアントの初期化は重い処理なので、ハンドラー外で行う

2. 環境変数を使用して設定を外部化する
   - ハードコーディングを避け、環境ごとに設定を変更可能にする

3. 適切なエラーハンドリングを実装する
   - ユーザーエラー（400系）とシステムエラー（500系）を区別する
   - エラーメッセージは具体的だが、機密情報は含めない

4. 構造化ログを使用する
   - JSON 形式のログは CloudWatch Logs Insights で検索しやすい

5. べき等性を考慮する
   - 同じリクエストが複数回来ても問題ないように設計する
"""

import json
import logging
import os
import uuid
from datetime import datetime

import boto3 # pyright: ignore[reportMissingImports]
from botocore.exceptions import ClientError # pyright: ignore[reportMissingImports]

# ============================================================================
# ロガーの設定
# ============================================================================
# Lambda では print() より logging モジュールを使用することを推奨
# - ログレベルの制御が可能
# - 構造化ログの出力が容易
# - CloudWatch Logs との統合が良好
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ============================================================================
# AWS クライアントの初期化（ハンドラー外で行う - ベストプラクティス）
# ============================================================================
# Lambda の実行環境（コンテナ）は再利用されることがある
# ハンドラー外で初期化したオブジェクトは、次回の呼び出しでも使い回される
# これにより、コールドスタート時のオーバーヘッドを削減できる
sqs_client = boto3.client('sqs')

# 環境変数から設定を取得
# Lambda コンソールまたは Terraform で設定する
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')


def validate_order(order_data: dict) -> tuple[bool, str]:
    """
    注文データのバリデーションを行う
    
    【バリデーションのベストプラクティス】
    - 必須フィールドの存在チェック
    - データ型のチェック
    - 値の範囲チェック
    - 早期リターンパターンで可読性を向上
    
    Args:
        order_data: 検証する注文データ
        
    Returns:
        tuple: (成功フラグ, エラーメッセージ)
    """
    # 必須フィールドのチェック
    required_fields = ['customer_name', 'items', 'total_amount']
    
    for field in required_fields:
        if field not in order_data:
            return False, f"必須フィールド '{field}' がありません"
    
    # customer_name のバリデーション
    if not isinstance(order_data['customer_name'], str):
        return False, "customer_name は文字列である必要があります"
    
    if len(order_data['customer_name'].strip()) == 0:
        return False, "customer_name は空にできません"
    
    # items のバリデーション
    if not isinstance(order_data['items'], list):
        return False, "items は配列である必要があります"
    
    if len(order_data['items']) == 0:
        return False, "items は少なくとも1つの商品を含む必要があります"
    
    # 各商品のバリデーション
    for i, item in enumerate(order_data['items']):
        if not isinstance(item, dict):
            return False, f"items[{i}] はオブジェクトである必要があります"
        
        # 商品の必須フィールド
        item_required = ['name', 'quantity', 'price']
        for field in item_required:
            if field not in item:
                return False, f"items[{i}] に '{field}' がありません"
        
        # 数値のバリデーション
        if not isinstance(item['quantity'], int) or item['quantity'] <= 0:
            return False, f"items[{i}].quantity は正の整数である必要があります"
        
        if not isinstance(item['price'], (int, float)) or item['price'] < 0:
            return False, f"items[{i}].price は0以上の数値である必要があります"
    
    # total_amount のバリデーション
    if not isinstance(order_data['total_amount'], (int, float)):
        return False, "total_amount は数値である必要があります"
    
    if order_data['total_amount'] < 0:
        return False, "total_amount は0以上である必要があります"
    
    return True, ""


def create_response(status_code: int, body: dict) -> dict:
    """
    API Gateway 用のレスポンスを作成する
    
    【API Gateway Lambda プロキシ統合のレスポンス形式】
    - statusCode: HTTP ステータスコード
    - headers: レスポンスヘッダー（CORS 対応に必要）
    - body: レスポンスボディ（文字列である必要がある）
    
    Args:
        status_code: HTTP ステータスコード
        body: レスポンスボディ（辞書）
        
    Returns:
        dict: API Gateway 形式のレスポンス
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            # CORS ヘッダー（必要に応じて設定）
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps(body, ensure_ascii=False)  # 日本語を正しく出力
    }


def lambda_handler(event, context):
    """
    Lambda のメインハンドラー関数
    
    【ハンドラーの引数】
    - event: トリガーからのイベントデータ
      - API Gateway の場合: HTTP リクエスト情報（headers, body, pathParameters など）
    - context: Lambda の実行コンテキスト
      - function_name: 関数名
      - memory_limit_in_mb: メモリ制限
      - aws_request_id: リクエストID（ログのトレースに使用）
      - get_remaining_time_in_millis(): 残り実行時間
    
    Args:
        event: API Gateway からのイベント
        context: Lambda 実行コンテキスト
        
    Returns:
        dict: API Gateway 形式のレスポンス
    """
    # リクエスト開始のログ
    # request_id を含めることで、CloudWatch Logs でトレースしやすくなる
    request_id = context.aws_request_id
    logger.info(json.dumps({
        'message': 'リクエストを受信しました',
        'request_id': request_id,
        'event': event
    }, ensure_ascii=False))
    
    try:
        # ============================================================
        # 環境変数のチェック
        # ============================================================
        if not SQS_QUEUE_URL:
            logger.error('SQS_QUEUE_URL 環境変数が設定されていません')
            return create_response(500, {
                'error': 'サーバー設定エラー',
                'message': 'キューの設定が正しくありません'
            })
        
        # ============================================================
        # リクエストボディのパース
        # ============================================================
        # API Gateway Lambda プロキシ統合では、body は文字列として渡される
        body = event.get('body')
        
        if body is None:
            logger.warning('リクエストボディが空です')
            return create_response(400, {
                'error': 'Bad Request',
                'message': 'リクエストボディが必要です'
            })
        
        # body が文字列の場合は JSON パース
        # テスト時などで直接 dict が渡される場合もあるので対応
        if isinstance(body, str):
            try:
                order_data = json.loads(body)
            except json.JSONDecodeError as e:
                logger.warning(f'JSON パースエラー: {str(e)}')
                return create_response(400, {
                    'error': 'Bad Request',
                    'message': 'リクエストボディが正しい JSON 形式ではありません'
                })
        else:
            order_data = body
        
        # ============================================================
        # バリデーション
        # ============================================================
        is_valid, error_message = validate_order(order_data)
        
        if not is_valid:
            logger.warning(f'バリデーションエラー: {error_message}')
            return create_response(400, {
                'error': 'Validation Error',
                'message': error_message
            })
        
        # ============================================================
        # 注文IDの生成
        # ============================================================
        # UUID v4 を使用してユニークな注文IDを生成
        # UUID は衝突の可能性が極めて低い（2^122 通り）
        order_id = str(uuid.uuid4())
        
        # 注文データに追加情報を付与
        order_message = {
            'order_id': order_id,
            'created_at': datetime.utcnow().isoformat() + 'Z',  # ISO 8601 形式（UTC）
            'customer_name': order_data['customer_name'],
            'items': order_data['items'],
            'total_amount': order_data['total_amount'],
            'request_id': request_id  # トレース用
        }
        
        # ============================================================
        # SQS へのメッセージ送信
        # ============================================================
        logger.info(json.dumps({
            'message': 'SQS にメッセージを送信します',
            'order_id': order_id,
            'queue_url': SQS_QUEUE_URL
        }, ensure_ascii=False))
        
        try:
            # SQS にメッセージを送信
            # MessageBody: 送信するメッセージ本文
            # MessageAttributes: メタデータ（オプション）
            response = sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(order_message, ensure_ascii=False),
                # メッセージ属性を使用すると、Consumer 側でフィルタリングが可能
                MessageAttributes={
                    'OrderType': {
                        'DataType': 'String',
                        'StringValue': 'NEW_ORDER'
                    },
                    'Priority': {
                        'DataType': 'String',
                        'StringValue': 'NORMAL'
                    }
                }
            )
            
            message_id = response['MessageId']
            logger.info(json.dumps({
                'message': 'SQS へのメッセージ送信が成功しました',
                'order_id': order_id,
                'message_id': message_id
            }, ensure_ascii=False))
            
        except ClientError as e:
            # AWS サービスのエラー
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            logger.error(json.dumps({
                'message': 'SQS へのメッセージ送信に失敗しました',
                'error_code': error_code,
                'error_message': error_message,
                'order_id': order_id
            }, ensure_ascii=False))
            
            return create_response(500, {
                'error': 'Internal Server Error',
                'message': '注文の処理中にエラーが発生しました。しばらく経ってから再度お試しください。'
            })
        
        # ============================================================
        # 成功レスポンス
        # ============================================================
        logger.info(json.dumps({
            'message': '注文を正常に受け付けました',
            'order_id': order_id
        }, ensure_ascii=False))
        
        # 201 Created: リソースが正常に作成されたことを示す
        return create_response(201, {
            'message': '注文を受け付けました',
            'order_id': order_id,
            'status': 'PENDING'
        })
        
    except Exception as e:
        # 予期しないエラーのキャッチ
        # 本番環境では詳細なエラー情報をクライアントに返さない（セキュリティ対策）
        logger.exception(json.dumps({
            'message': '予期しないエラーが発生しました',
            'error': str(e),
            'error_type': type(e).__name__
        }, ensure_ascii=False))
        
        return create_response(500, {
            'error': 'Internal Server Error',
            'message': 'サーバーエラーが発生しました'
        })
