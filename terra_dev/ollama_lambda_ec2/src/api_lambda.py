# pyright: reportMissingImports=false

from __future__ import annotations

import json
import os
import time
import uuid
from typing import Any

import boto3
from botocore.config import Config

from common import LOGGER, RequestError, build_status_url, json_response, parse_generate_request, require_api_key, utc_now_iso

DYNAMODB = boto3.resource("dynamodb")
REQUESTS_TABLE = DYNAMODB.Table(os.environ["REQUESTS_TABLE_NAME"])
QUEUE_URL = os.environ["REQUEST_QUEUE_URL"]
QUEUE_GROUP_ID = os.environ.get("REQUEST_QUEUE_GROUP_ID", "ollama")
REQUEST_STATUS_TTL_HOURS = int(os.environ.get("REQUEST_STATUS_TTL_HOURS", "168"))
SQS_CLIENT = boto3.client(
    "sqs",
    config=Config(retries={"max_attempts": 2, "mode": "standard"}),
)


def _mark_enqueue_failed(request_id: str, message: str) -> None:
    now_iso = utc_now_iso()
    REQUESTS_TABLE.update_item(
        Key={"request_id": request_id},
        UpdateExpression=(
            "SET #status = :status, updated_at = :updated_at, completed_at = :completed_at, "
            "error_message = :error_message, error_type = :error_type"
        ),
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "FAILED",
            ":updated_at": now_iso,
            ":completed_at": now_iso,
            ":error_message": message,
            ":error_type": "EnqueueFailed",
        },
    )


def _handle_generate(event: dict[str, Any], request_id: str) -> dict[str, Any]:
    prompt, model = parse_generate_request(event)
    now_iso = utc_now_iso()
    expires_at = int(time.time()) + (REQUEST_STATUS_TTL_HOURS * 3600)

    REQUESTS_TABLE.put_item(
        Item={
            "request_id": request_id,
            "status": "QUEUED",
            "model": model,
            "created_at": now_iso,
            "updated_at": now_iso,
            "expires_at": expires_at,
        },
        ConditionExpression="attribute_not_exists(request_id)",
    )

    try:
        SQS_CLIENT.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(
                {
                    "request_id": request_id,
                    "prompt": prompt,
                    "model": model,
                },
                ensure_ascii=False,
            ),
            MessageGroupId=QUEUE_GROUP_ID,
            MessageDeduplicationId=request_id,
        )
    except Exception:
        LOGGER.exception("Failed to enqueue request_id=%s", request_id)
        _mark_enqueue_failed(request_id, "Failed to enqueue request for asynchronous processing.")
        raise

    return json_response(
        202,
        {
            "request_id": request_id,
            "status": "QUEUED",
            "status_url": build_status_url(event, request_id),
        },
    )


def _handle_request_status(request_id: str) -> dict[str, Any]:
    item = REQUESTS_TABLE.get_item(Key={"request_id": request_id}).get("Item")
    if not item:
        raise RequestError(404, "Request not found.")

    body: dict[str, Any] = {
        "request_id": request_id,
        "status": item["status"],
        "model": item.get("model"),
        "created_at": item.get("created_at"),
        "updated_at": item.get("updated_at"),
    }

    if item["status"] == "SUCCEEDED" and item.get("result_json"):
        body["result"] = json.loads(item["result_json"])

    if item["status"] == "FAILED":
        body["error"] = {
            "message": item.get("error_message", "Request processing failed."),
            "type": item.get("error_type"),
        }
        if item.get("error_details_json"):
            body["error"]["details"] = json.loads(item["error_details_json"])

    if item.get("completed_at"):
        body["completed_at"] = item["completed_at"]

    return json_response(200, body)


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_id = getattr(context, "aws_request_id", uuid.uuid4().hex)
    route_key = event.get("routeKey", "")
    LOGGER.info("Handling API request_id=%s route_key=%s", request_id, route_key)

    try:
        require_api_key(event.get("headers"))

        if route_key == "POST /generate":
            return _handle_generate(event, request_id=request_id)

        if route_key == "GET /requests/{request_id}":
            status_request_id = (event.get("pathParameters") or {}).get("request_id", "").strip()
            if not status_request_id:
                raise RequestError(400, "request_id path parameter is required.")
            return _handle_request_status(status_request_id)

        return json_response(404, {"message": f"Unsupported route: {route_key or 'unknown'}"})
    except RequestError as exc:
        return json_response(exc.status_code, {"message": exc.message})
    except Exception:
        LOGGER.exception("Unhandled error while processing API request_id=%s", request_id)
        return json_response(500, {"message": "Internal server error."})