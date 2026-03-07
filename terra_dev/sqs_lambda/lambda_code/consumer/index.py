"""
Consumer Lambda 関数
=====================
SQS キューからメッセージを受信し、注文を処理して DynamoDB に保存する

【SQS トリガーの Lambda ベストプラクティス】
1. バッチ処理を考慮する
   - SQS は複数のメッセージをまとめて Lambda に渡す（バッチサイズ設定可能）
   - 各メッセージを個別に処理し、部分的な失敗に対応する

2. べき等性を確保する
   - SQS は「少なくとも1回」の配信を保証するため、同じメッセージが複数回届く可能性がある
   - order_id をキーにして DynamoDB の条件付き書き込みを使用する

3. エラーハンドリング
   - 処理失敗時は例外をスローしてリトライを促す
   - デッドレターキュー（DLQ）と組み合わせて、失敗したメッセージを別キューに退避

4. 部分バッチ応答
   - batchItemFailures を返すことで、失敗したメッセージのみリトライ可能
   - 成功したメッセージは削除される

5. タイムアウト設定
   - Lambda のタイムアウトは、SQS の可視性タイムアウトより短く設定する
   - これにより、タイムアウト時にメッセージが再処理される
"""

import json
import logging
import os
from datetime import datetime, timedelta
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

# ============================================================================
# ロガーの設定
# ============================================================================
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ============================================================================
# AWS クライアントの初期化（ハンドラー外で行う）
# ============================================================================
# DynamoDB リソース（高レベル API）を使用
# Table クラスを使用すると、より Pythonic なコードが書ける
dynamodb = boto3.resource('dynamodb')

# 環境変数から設定を取得
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

# テーブルオブジェクトの取得
# 注意: テーブルが存在しない場合でも、この時点ではエラーにならない
# 実際のアクセス時にエラーになる
table = dynamodb.Table(DYNAMODB_TABLE_NAME) if DYNAMODB_TABLE_NAME else None


class OrderProcessingError(Exception):
    """
    注文処理のカスタム例外
    
    【カスタム例外のベストプラクティス】
    - 特定のエラー種別を識別しやすくする
    - エラーメッセージに必要なコンテキストを含める
    - リトライ可能かどうかの判断に使用できる
    """
    def __init__(self, message: str, order_id: str = None, retryable: bool = True):
        self.message = message
        self.order_id = order_id
        self.retryable = retryable
        super().__init__(self.message)


def convert_to_decimal(obj):
    """
    Python の float を DynamoDB 用の Decimal に変換する
    
    【DynamoDB と数値型】
    DynamoDB は float を直接サポートしていない
    boto3 の Table リソースを使用する場合、float は Decimal に変換する必要がある
    
    Args:
        obj: 変換するオブジェクト（dict, list, float, その他）
        
    Returns:
        Decimal に変換されたオブジェクト
    """
    if isinstance(obj, float):
        return Decimal(str(obj))
    elif isinstance(obj, dict):
        return {k: convert_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_to_decimal(item) for item in obj]
    return obj


def process_order(order_data: dict) -> dict:
    """
    注文を処理する（ビジネスロジック）
    
    【実際のユースケース例】
    - 在庫の確認・引き当て
    - 決済処理の実行
    - 外部システムへの通知
    - メール送信
    
    この学習用コードでは、処理をシミュレーションしてログ出力のみ行う
    
    Args:
        order_data: 注文データ
        
    Returns:
        dict: 処理結果
    """
    order_id = order_data.get('order_id', 'unknown')
    customer_name = order_data.get('customer_name', 'unknown')
    items = order_data.get('items', [])
    total_amount = order_data.get('total_amount', 0)
    
    logger.info(json.dumps({
        'message': '=== 注文処理を開始します ===',
        'order_id': order_id,
        'customer_name': customer_name,
        'item_count': len(items),
        'total_amount': total_amount
    }, ensure_ascii=False))
    
    # 各商品の処理をシミュレーション
    for i, item in enumerate(items):
        item_name = item.get('name', 'unknown')
        quantity = item.get('quantity', 0)
        price = item.get('price', 0)
        
        logger.info(json.dumps({
            'message': f'商品 {i + 1} を処理中',
            'order_id': order_id,
            'item_name': item_name,
            'quantity': quantity,
            'price': price,
            'subtotal': quantity * price
        }, ensure_ascii=False))
        
        # 実際の処理をここに実装
        # 例: 在庫確認、引き当て処理など
    
    logger.info(json.dumps({
        'message': '=== 注文処理が完了しました ===',
        'order_id': order_id,
        'status': 'COMPLETED'
    }, ensure_ascii=False))
    
    return {
        'status': 'COMPLETED',
        'processed_at': datetime.utcnow().isoformat() + 'Z'
    }


def save_to_dynamodb(order_data: dict, processing_result: dict) -> None:
    """
    処理結果を DynamoDB に保存する
    
    【DynamoDB のベストプラクティス】
    1. 条件付き書き込み
       - ConditionExpression を使用して、べき等な書き込みを実現
       - 既存データの上書き防止や楽観的ロックに使用
    
    2. TTL（Time To Live）
       - expires_at 属性を使用して、自動的に古いデータを削除
       - UNIX タイムスタンプ（秒）で指定する必要がある
    
    3. エラーハンドリング
       - ClientError をキャッチして、適切に処理
       - 条件チェック失敗は正常なケース（既に処理済み）として扱う
    
    Args:
        order_data: 元の注文データ
        processing_result: 処理結果
        
    Raises:
        OrderProcessingError: DynamoDB への保存に失敗した場合
    """
    if not table:
        raise OrderProcessingError(
            'DYNAMODB_TABLE_NAME 環境変数が設定されていません',
            order_data.get('order_id'),
            retryable=False  # 設定エラーはリトライしても解決しない
        )
    
    order_id = order_data.get('order_id')
    
    # TTL の計算（30日後）
    # DynamoDB TTL は UNIX タイムスタンプ（秒）で指定
    ttl_days = 30
    expires_at = int((datetime.utcnow() + timedelta(days=ttl_days)).timestamp())
    
    # 保存するアイテムの作成
    item = {
        'order_id': order_id,  # パーティションキー
        'created_at': order_data.get('created_at'),
        'customer_name': order_data.get('customer_name'),
        'items': convert_to_decimal(order_data.get('items', [])),
        'total_amount': convert_to_decimal(order_data.get('total_amount', 0)),
        'status': processing_result.get('status'),
        'processed_at': processing_result.get('processed_at'),
        'expires_at': expires_at,  # TTL 用
        # トレース用の情報
        'request_id': order_data.get('request_id')
    }
    
    logger.info(json.dumps({
        'message': 'DynamoDB にデータを保存します',
        'order_id': order_id,
        'table_name': DYNAMODB_TABLE_NAME
    }, ensure_ascii=False))
    
    try:
        # 条件付き書き込み
        # order_id が存在しない場合のみ書き込む（べき等性の確保）
        table.put_item(
            Item=item,
            # 条件: order_id 属性が存在しない場合のみ書き込む
            ConditionExpression='attribute_not_exists(order_id)'
        )
        
        logger.info(json.dumps({
            'message': 'DynamoDB への保存が成功しました',
            'order_id': order_id
        }, ensure_ascii=False))
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        
        if error_code == 'ConditionalCheckFailedException':
            # 既に同じ order_id のデータが存在する
            # これは正常なケース（重複処理の防止）
            logger.warning(json.dumps({
                'message': '注文は既に処理済みです（べき等性チェック）',
                'order_id': order_id
            }, ensure_ascii=False))
            # エラーをスローせず、正常終了とする
            return
        
        # その他の DynamoDB エラー
        logger.error(json.dumps({
            'message': 'DynamoDB への保存に失敗しました',
            'order_id': order_id,
            'error_code': error_code,
            'error_message': e.response['Error']['Message']
        }, ensure_ascii=False))
        
        raise OrderProcessingError(
            f'DynamoDB への保存に失敗しました: {error_code}',
            order_id,
            retryable=True
        )


def process_single_message(record: dict) -> None:
    """
    単一の SQS メッセージを処理する
    
    【SQS メッセージの構造】
    - messageId: メッセージの一意識別子
    - receiptHandle: メッセージ削除時に使用（Lambda トリガーでは自動処理）
    - body: メッセージ本文
    - attributes: システム属性（送信時刻、受信回数など）
    - messageAttributes: ユーザー定義属性
    
    Args:
        record: SQS メッセージレコード
        
    Raises:
        OrderProcessingError: 処理に失敗した場合
    """
    message_id = record.get('messageId', 'unknown')
    
    logger.info(json.dumps({
        'message': 'メッセージの処理を開始します',
        'message_id': message_id,
        # 受信回数を確認（リトライ状況の把握に有用）
        'approximate_receive_count': record.get('attributes', {}).get('ApproximateReceiveCount', '1')
    }, ensure_ascii=False))
    
    # メッセージボディのパース
    try:
        body = record.get('body', '{}')
        order_data = json.loads(body)
    except json.JSONDecodeError as e:
        logger.error(json.dumps({
            'message': 'メッセージのパースに失敗しました',
            'message_id': message_id,
            'error': str(e)
        }, ensure_ascii=False))
        # パースエラーはリトライしても解決しないため、リトライ不可とする
        raise OrderProcessingError(
            'メッセージのパースに失敗しました',
            retryable=False
        )
    
    order_id = order_data.get('order_id', 'unknown')
    
    # 注文処理の実行
    processing_result = process_order(order_data)
    
    # DynamoDB への保存
    save_to_dynamodb(order_data, processing_result)
    
    logger.info(json.dumps({
        'message': 'メッセージの処理が完了しました',
        'message_id': message_id,
        'order_id': order_id
    }, ensure_ascii=False))


def lambda_handler(event, context):
    """
    Lambda のメインハンドラー関数
    
    【SQS トリガーのイベント構造】
    {
        "Records": [
            {
                "messageId": "...",
                "receiptHandle": "...",
                "body": "...",
                "attributes": {...},
                "messageAttributes": {...},
                "eventSource": "aws:sqs",
                "eventSourceARN": "arn:aws:sqs:..."
            },
            ...
        ]
    }
    
    【部分バッチ応答（Partial Batch Response）】
    Lambda 関数で ReportBatchItemFailures を有効にすると、
    失敗したメッセージのみをリトライできる
    
    成功したメッセージは SQS から削除され、
    失敗したメッセージは可視性タイムアウト後に再処理される
    
    Args:
        event: SQS からのイベント
        context: Lambda 実行コンテキスト
        
    Returns:
        dict: 部分バッチ応答（失敗したメッセージのリスト）
    """
    logger.info(json.dumps({
        'message': 'Lambda 関数が起動しました',
        'request_id': context.aws_request_id,
        'record_count': len(event.get('Records', []))
    }, ensure_ascii=False))
    
    # 失敗したメッセージを追跡するリスト
    # 部分バッチ応答で使用
    batch_item_failures = []
    
    # 各メッセージを処理
    records = event.get('Records', [])
    
    for record in records:
        message_id = record.get('messageId', 'unknown')
        
        try:
            # 単一メッセージの処理
            process_single_message(record)
            
        except OrderProcessingError as e:
            # カスタム例外の処理
            logger.error(json.dumps({
                'message': '注文処理エラー',
                'message_id': message_id,
                'order_id': e.order_id,
                'error': e.message,
                'retryable': e.retryable
            }, ensure_ascii=False))
            
            if e.retryable:
                # リトライ可能なエラーの場合、失敗リストに追加
                batch_item_failures.append({
                    'itemIdentifier': message_id
                })
            # リトライ不可の場合は、失敗リストに追加しない
            # → メッセージは削除され、DLQ に送られる（DLQ 設定がある場合）
            
        except Exception as e:
            # 予期しないエラー
            logger.exception(json.dumps({
                'message': '予期しないエラーが発生しました',
                'message_id': message_id,
                'error': str(e),
                'error_type': type(e).__name__
            }, ensure_ascii=False))
            
            # 予期しないエラーはリトライする
            batch_item_failures.append({
                'itemIdentifier': message_id
            })
    
    # 処理結果のサマリーをログ出力
    success_count = len(records) - len(batch_item_failures)
    failure_count = len(batch_item_failures)
    
    logger.info(json.dumps({
        'message': 'バッチ処理が完了しました',
        'total_records': len(records),
        'success_count': success_count,
        'failure_count': failure_count
    }, ensure_ascii=False))
    
    # 部分バッチ応答を返す
    # これにより、失敗したメッセージのみがリトライされる
    # 注意: Lambda の SQS トリガー設定で ReportBatchItemFailures を有効にする必要がある
    return {
        'batchItemFailures': batch_item_failures
    }
