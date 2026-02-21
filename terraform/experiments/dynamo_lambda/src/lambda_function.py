"""
DynamoDB CRUD API Lambda関数

API Gateway（プロキシ統合）経由のHTTPリクエストを処理し、
DynamoDBテーブルに対してCRUD操作を実行する。

エンドポイント:
  GET    /items       - アイテム一覧取得
  GET    /items/{id}  - アイテム個別取得
  POST   /items       - アイテム作成
  PUT    /items/{id}  - アイテム更新
  DELETE /items/{id}  - アイテム削除
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

# ロガーの設定
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# DynamoDBリソースの初期化
# Lambda関数のコールドスタート時に1回だけ実行される（コネクションの再利用）
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE_NAME"])


class DecimalEncoder(json.JSONEncoder):
    """DynamoDBのDecimal型をJSONシリアライズ可能にするカスタムエンコーダー

    DynamoDBはNumber型をPythonのDecimal型として返すが、
    json.dumpsはDecimalをシリアライズできないため、floatまたはintに変換する。
    """

    def default(self, obj):
        if isinstance(obj, Decimal):
            # 整数の場合はintに、小数の場合はfloatに変換
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def build_response(status_code, body):
    """API Gatewayプロキシ統合用のレスポンスを構築する

    Args:
        status_code: HTTPステータスコード
        body: レスポンスボディ（辞書）

    Returns:
        API Gatewayプロキシ統合形式のレスポンス辞書
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # CORS対応ヘッダー
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        },
        "body": json.dumps(body, cls=DecimalEncoder, ensure_ascii=False),
    }


def get_items():
    """アイテム一覧を取得する（Scan操作）

    注意: Scan操作はテーブル全体をスキャンするため、
    データ量が多い場合はパフォーマンスに注意が必要。
    本番環境ではページネーションやQuery操作の使用を検討すること。

    Returns:
        アイテム一覧を含むレスポンス
    """
    logger.info("Getting all items")
    response = table.scan()
    items = response.get("Items", [])

    logger.info(f"Found {len(items)} items")
    return build_response(200, {"items": items, "count": len(items)})


def get_item(item_id):
    """指定されたIDのアイテムを取得する（GetItem操作）

    Args:
        item_id: 取得するアイテムのID

    Returns:
        アイテムデータを含むレスポンス、または404エラー
    """
    logger.info(f"Getting item: {item_id}")
    response = table.get_item(Key={"id": item_id})
    item = response.get("Item")

    if not item:
        logger.warning(f"Item not found: {item_id}")
        return build_response(404, {"error": "Item not found", "id": item_id})

    return build_response(200, item)


def create_item(body):
    """新しいアイテムを作成する（PutItem操作）

    Args:
        body: リクエストボディ（nameフィールドが必須）

    Returns:
        作成されたアイテムデータを含むレスポンス
    """
    if not body or "name" not in body:
        return build_response(400, {"error": "'name' field is required"})

    # UUIDを自動生成してIDとする
    item_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "id": item_id,
        "name": body["name"],
        "description": body.get("description", ""),
        "created_at": now,
        "updated_at": now,
    }

    logger.info(f"Creating item: {item_id}")
    table.put_item(Item=item)

    return build_response(201, {"message": "Item created", "item": item})


def update_item(item_id, body):
    """指定されたIDのアイテムを更新する（UpdateItem操作）

    Args:
        item_id: 更新するアイテムのID
        body: リクエストボディ（更新するフィールドを含む）

    Returns:
        更新されたアイテムデータを含むレスポンス、または404エラー
    """
    if not body:
        return build_response(400, {"error": "Request body is required"})

    # 更新対象のアイテムが存在するか確認
    existing = table.get_item(Key={"id": item_id}).get("Item")
    if not existing:
        logger.warning(f"Item not found for update: {item_id}")
        return build_response(404, {"error": "Item not found", "id": item_id})

    now = datetime.now(timezone.utc).isoformat()

    # UpdateExpression を動的に構築
    # 更新可能なフィールド: name, description
    update_expressions = []
    expression_attribute_names = {}
    expression_attribute_values = {":updated_at": now}

    update_expressions.append("#updated_at = :updated_at")
    expression_attribute_names["#updated_at"] = "updated_at"

    if "name" in body:
        update_expressions.append("#name = :name")
        expression_attribute_names["#name"] = "name"
        expression_attribute_values[":name"] = body["name"]

    if "description" in body:
        update_expressions.append("#description = :description")
        expression_attribute_names["#description"] = "description"
        expression_attribute_values[":description"] = body["description"]

    logger.info(f"Updating item: {item_id}")
    response = table.update_item(
        Key={"id": item_id},
        UpdateExpression="SET " + ", ".join(update_expressions),
        ExpressionAttributeNames=expression_attribute_names,
        ExpressionAttributeValues=expression_attribute_values,
        ReturnValues="ALL_NEW",
    )

    return build_response(
        200, {"message": "Item updated", "item": response["Attributes"]}
    )


def delete_item(item_id):
    """指定されたIDのアイテムを削除する（DeleteItem操作）

    Args:
        item_id: 削除するアイテムのID

    Returns:
        削除結果を含むレスポンス、または404エラー
    """
    # 削除対象のアイテムが存在するか確認
    existing = table.get_item(Key={"id": item_id}).get("Item")
    if not existing:
        logger.warning(f"Item not found for delete: {item_id}")
        return build_response(404, {"error": "Item not found", "id": item_id})

    logger.info(f"Deleting item: {item_id}")
    table.delete_item(Key={"id": item_id})

    return build_response(200, {"message": "Item deleted", "id": item_id})


def lambda_handler(event, context):
    """Lambda関数のメインハンドラー

    API Gatewayプロキシ統合からのイベントを処理し、
    HTTPメソッドとリソースパスに基づいてCRUD操作を振り分ける。

    Args:
        event: API Gatewayプロキシ統合イベント
        context: Lambda実行コンテキスト

    Returns:
        API Gatewayプロキシ統合形式のレスポンス
    """
    logger.info(f"Received event: {json.dumps(event)}")

    http_method = event.get("httpMethod", "")
    resource = event.get("resource", "")
    path_parameters = event.get("pathParameters") or {}

    try:
        # リクエストボディのパース
        body = None
        if event.get("body"):
            body = json.loads(event["body"])

        # ルーティング: HTTPメソッドとリソースパスに基づいて処理を振り分け
        if resource == "/items" and http_method == "GET":
            return get_items()

        elif resource == "/items/{id}" and http_method == "GET":
            return get_item(path_parameters["id"])

        elif resource == "/items" and http_method == "POST":
            return create_item(body)

        elif resource == "/items/{id}" and http_method == "PUT":
            return update_item(path_parameters["id"], body)

        elif resource == "/items/{id}" and http_method == "DELETE":
            return delete_item(path_parameters["id"])

        else:
            return build_response(
                400,
                {
                    "error": "Unsupported route",
                    "method": http_method,
                    "resource": resource,
                },
            )

    except json.JSONDecodeError:
        logger.error("Invalid JSON in request body")
        return build_response(400, {"error": "Invalid JSON in request body"})

    except ClientError as e:
        logger.error(f"DynamoDB error: {e.response['Error']['Message']}")
        return build_response(
            500, {"error": "Internal server error", "detail": str(e)}
        )

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return build_response(500, {"error": "Internal server error"})
