# pyright: reportMissingImports=false

from __future__ import annotations

import json
import os
from typing import Any

import boto3

from common import LOGGER, OllamaInvocationError, forward_to_ollama, utc_now_iso

DYNAMODB = boto3.resource("dynamodb")
REQUESTS_TABLE = DYNAMODB.Table(os.environ["REQUESTS_TABLE_NAME"])


def _update_processing(request_id: str) -> None:
    now_iso = utc_now_iso()
    REQUESTS_TABLE.update_item(
        Key={"request_id": request_id},
        UpdateExpression="SET #status = :status, updated_at = :updated_at",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "PROCESSING",
            ":updated_at": now_iso,
        },
    )


def _update_succeeded(request_id: str, result: dict[str, Any]) -> None:
    now_iso = utc_now_iso()
    REQUESTS_TABLE.update_item(
        Key={"request_id": request_id},
        UpdateExpression="SET #status = :status, updated_at = :updated_at, completed_at = :completed_at, result_json = :result_json",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "SUCCEEDED",
            ":updated_at": now_iso,
            ":completed_at": now_iso,
            ":result_json": json.dumps(result, ensure_ascii=False),
        },
    )


def _update_failed(
    request_id: str,
    *,
    message: str,
    error_type: str,
    details: dict[str, Any] | None = None,
) -> None:
    now_iso = utc_now_iso()
    expression_values: dict[str, Any] = {
        ":status": "FAILED",
        ":updated_at": now_iso,
        ":completed_at": now_iso,
        ":error_message": message,
        ":error_type": error_type,
    }
    update_expression = (
        "SET #status = :status, updated_at = :updated_at, completed_at = :completed_at, "
        "error_message = :error_message, error_type = :error_type"
    )

    if details:
        expression_values[":error_details_json"] = json.dumps(details, ensure_ascii=False)
        update_expression += ", error_details_json = :error_details_json"

    REQUESTS_TABLE.update_item(
        Key={"request_id": request_id},
        UpdateExpression=update_expression,
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues=expression_values,
    )


def _process_record(record: dict[str, Any]) -> None:
    payload = json.loads(record["body"])
    request_id = str(payload.get("request_id", "")).strip()
    prompt = payload.get("prompt")
    model = payload.get("model")

    if not request_id or not isinstance(prompt, str) or not prompt.strip() or not isinstance(model, str) or not model.strip():
        LOGGER.error("Skipping malformed SQS message: %s", record.get("body", ""))
        return

    LOGGER.info("Worker started request_id=%s", request_id)
    _update_processing(request_id)

    try:
        result = forward_to_ollama(prompt=prompt.strip(), model=model.strip(), request_id=request_id)
        _update_succeeded(request_id, result)
        LOGGER.info("Worker finished request_id=%s successfully", request_id)
    except OllamaInvocationError as exc:
        LOGGER.warning("Worker failed request_id=%s message=%s", request_id, exc.message)
        _update_failed(
            request_id,
            message=exc.message,
            error_type="OllamaInvocationError",
            details=exc.details,
        )
    except Exception as exc:
        LOGGER.exception("Unexpected error while processing request_id=%s", request_id)
        _update_failed(
            request_id,
            message="Internal worker error.",
            error_type=type(exc).__name__,
        )


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    records = event.get("Records") or []
    LOGGER.info("Received %s SQS record(s)", len(records))

    for record in records:
        _process_record(record)

    return {"batchItemFailures": []}