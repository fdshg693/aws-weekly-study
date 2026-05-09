from __future__ import annotations

import base64
import json
import logging
import os
import uuid
from datetime import UTC, datetime
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

DYNAMODB = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("PROMPTS_TABLE_NAME", "")
INDEX_NAME = os.environ.get("ACCESS_PATTERN_INDEX_NAME", "access_pattern_index")
DEFAULT_LIMIT = int(os.environ.get("DEFAULT_PROMPT_LIST_LIMIT", "20"))
MAX_LIMIT = int(os.environ.get("MAX_PROMPT_LIST_LIMIT", "100"))
CORS_ALLOW_ORIGIN = os.environ.get("CORS_ALLOW_ORIGIN", "*")


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    """Entry point for API Gateway REST API proxy requests."""
    try:
        method = (event or {}).get("httpMethod", "")
        resource = (event or {}).get("resource", "")
        path = ((event or {}).get("path") or "").rstrip("/") or "/"
        path_parameters = (event or {}).get("pathParameters") or {}
        prompt_id = path_parameters.get("id")
        is_collection_route = resource == "/prompts" or path.endswith("/prompts") or path == "/prompts"

        if method == "OPTIONS":
            return response(200, {"message": "ok"})

        if method == "GET" and not prompt_id and is_collection_route:
            return list_prompts(event)

        if method == "POST" and is_collection_route:
            return create_prompt(event)

        if prompt_id and method == "GET":
            return get_prompt(prompt_id)

        if prompt_id and method == "PUT":
            return update_prompt(prompt_id, event)

        if prompt_id and method == "DELETE":
            return delete_prompt(prompt_id)

        return response(404, {"message": "Route not found"})
    except BadRequestError as error:
        return response(400, {"message": str(error)})
    except NotFoundError as error:
        return response(404, {"message": str(error)})
    except ClientError as error:
        LOGGER.exception("AWS client error")
        return response(500, {"message": "AWS operation failed", "detail": error.response.get("Error", {}).get("Message", "Unknown error")})
    except Exception:
        LOGGER.exception("Unhandled error")
        return response(500, {"message": "Internal server error"})


class BadRequestError(Exception):
    """Raised when the request payload is invalid."""


class NotFoundError(Exception):
    """Raised when the requested prompt cannot be found."""


def get_table():
    if not TABLE_NAME:
        raise RuntimeError("PROMPTS_TABLE_NAME environment variable is not set")
    return DYNAMODB.Table(TABLE_NAME)


def response(status_code: int, body: dict[str, Any] | None = None) -> dict[str, Any]:
    headers = {
        "Access-Control-Allow-Origin": CORS_ALLOW_ORIGIN,
        "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "OPTIONS,GET,POST,PUT,DELETE",
    }

    if body is None:
        return {
            "statusCode": status_code,
            "headers": headers,
            "body": "",
        }

    headers["Content-Type"] = "application/json"
    return {
        "statusCode": status_code,
        "headers": headers,
        "body": json.dumps(body, ensure_ascii=False),
    }


def list_prompts(event: dict[str, Any]) -> dict[str, Any]:
    query = event.get("queryStringParameters") or {}
    tag = normalize_tag(query.get("tag")) if query.get("tag") else None
    limit = parse_limit(query.get("limit"))
    exclusive_start_key = decode_next_token(query.get("next_token"))

    params: dict[str, Any] = {
        "IndexName": INDEX_NAME,
        "KeyConditionExpression": Key("access_pk").eq(f"TAG#{tag}" if tag else "PROMPT"),
        "Limit": limit,
        "ScanIndexForward": False,
    }

    if exclusive_start_key:
        params["ExclusiveStartKey"] = exclusive_start_key

    result = get_table().query(**params)
    items = [to_summary_item(item) for item in result.get("Items", [])]

    return response(
        200,
        {
          "items": items,
          "count": len(items),
          "next_token": encode_next_token(result.get("LastEvaluatedKey")),
        },
    )


def get_prompt(prompt_id: str) -> dict[str, Any]:
    item = load_prompt(prompt_id)
    return response(200, {"item": to_public_prompt_item(item)})


def create_prompt(event: dict[str, Any]) -> dict[str, Any]:
    payload = parse_json_body(event)
    prompt_id = str(uuid.uuid4())
    now = current_timestamp()
    item = build_prompt_item(prompt_id=prompt_id, payload=payload, created_at=now, updated_at=now)

    table = get_table()
    table.put_item(
        Item=item,
        ConditionExpression="attribute_not_exists(id)",
    )

    for tag_item in build_tag_items(item):
        table.put_item(Item=tag_item)

    return response(201, {"item": to_public_prompt_item(item)})


def update_prompt(prompt_id: str, event: dict[str, Any]) -> dict[str, Any]:
    existing = load_prompt(prompt_id)
    payload = parse_json_body(event)
    updated = build_prompt_item(
        prompt_id=prompt_id,
        payload=payload,
        created_at=existing["created_at"],
        updated_at=current_timestamp(),
    )

    table = get_table()
    table.put_item(Item=updated)

    for tag in existing.get("tags", []):
        table.delete_item(Key={"id": tag_index_id(tag, prompt_id)})

    for tag_item in build_tag_items(updated):
        table.put_item(Item=tag_item)

    return response(200, {"item": to_public_prompt_item(updated)})


def delete_prompt(prompt_id: str) -> dict[str, Any]:
    existing = load_prompt(prompt_id)
    table = get_table()

    for tag in existing.get("tags", []):
        table.delete_item(Key={"id": tag_index_id(tag, prompt_id)})

    table.delete_item(Key={"id": prompt_id})
    return response(204)


def load_prompt(prompt_id: str) -> dict[str, Any]:
    result = get_table().get_item(Key={"id": prompt_id})
    item = result.get("Item")

    if not item or item.get("entity_type") != "PROMPT":
        raise NotFoundError(f"Prompt not found: {prompt_id}")

    return item


def parse_json_body(event: dict[str, Any]) -> dict[str, Any]:
    raw_body = event.get("body")
    if raw_body is None:
        raise BadRequestError("Request body is required")

    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as error:
        raise BadRequestError("Request body must be valid JSON") from error

    if not isinstance(payload, dict):
        raise BadRequestError("Request body must be a JSON object")

    return payload


def build_prompt_item(*, prompt_id: str, payload: dict[str, Any], created_at: str, updated_at: str) -> dict[str, Any]:
    name = require_non_empty_string(payload.get("name"), "name")
    prompt_text = require_non_empty_string(payload.get("prompt_text"), "prompt_text")
    description = optional_string(payload.get("description"))
    target_model = optional_string(payload.get("target_model"))
    version = optional_string(payload.get("version")) or "v1"
    variables = normalize_string_list(payload.get("variables"), field_name="variables")
    tags = normalize_tags(payload.get("tags", []))
    is_active = payload.get("is_active", True)

    if not isinstance(is_active, bool):
        raise BadRequestError("is_active must be a boolean")

    return {
        "id": prompt_id,
        "entity_type": "PROMPT",
        "name": name,
        "description": description,
        "prompt_text": prompt_text,
        "variables": variables,
        "tags": tags,
        "target_model": target_model,
        "version": version,
        "is_active": is_active,
        "created_at": created_at,
        "updated_at": updated_at,
        "access_pk": "PROMPT",
        "access_sk": f"{created_at}#{prompt_id}",
    }


def build_tag_items(prompt_item: dict[str, Any]) -> list[dict[str, Any]]:
    tag_items: list[dict[str, Any]] = []
    for tag in prompt_item.get("tags", []):
        tag_items.append(
            {
                "id": tag_index_id(tag, prompt_item["id"]),
                "entity_type": "PROMPT_TAG",
                "prompt_id": prompt_item["id"],
                "tag": tag,
                "name": prompt_item["name"],
                "description": prompt_item["description"],
                "tags": prompt_item["tags"],
                "target_model": prompt_item["target_model"],
                "version": prompt_item["version"],
                "is_active": prompt_item["is_active"],
                "created_at": prompt_item["created_at"],
                "updated_at": prompt_item["updated_at"],
                "access_pk": f"TAG#{tag}",
                "access_sk": prompt_item["access_sk"],
            }
        )

    return tag_items


def to_summary_item(item: dict[str, Any]) -> dict[str, Any]:
    prompt_id = item.get("prompt_id") or item["id"]
    return {
        "id": prompt_id,
        "name": item.get("name", ""),
        "description": item.get("description", ""),
        "tags": item.get("tags", []),
        "target_model": item.get("target_model", ""),
        "version": item.get("version", ""),
        "is_active": item.get("is_active", True),
        "created_at": item.get("created_at", ""),
        "updated_at": item.get("updated_at", ""),
    }


def to_public_prompt_item(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": item["id"],
        "name": item.get("name", ""),
        "description": item.get("description", ""),
        "prompt_text": item.get("prompt_text", ""),
        "variables": item.get("variables", []),
        "tags": item.get("tags", []),
        "target_model": item.get("target_model", ""),
        "version": item.get("version", ""),
        "is_active": item.get("is_active", True),
        "created_at": item.get("created_at", ""),
        "updated_at": item.get("updated_at", ""),
    }


def parse_limit(raw_limit: Any) -> int:
    if raw_limit in (None, ""):
        return DEFAULT_LIMIT

    try:
        limit = int(raw_limit)
    except (TypeError, ValueError) as error:
        raise BadRequestError("limit must be an integer") from error

    if limit < 1 or limit > MAX_LIMIT:
        raise BadRequestError(f"limit must be between 1 and {MAX_LIMIT}")

    return limit


def encode_next_token(last_evaluated_key: dict[str, Any] | None) -> str | None:
    if not last_evaluated_key:
        return None

    raw = json.dumps(last_evaluated_key, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8")


def decode_next_token(next_token: str | None) -> dict[str, Any] | None:
    if not next_token:
        return None

    try:
        raw = base64.urlsafe_b64decode(next_token.encode("utf-8"))
        value = json.loads(raw.decode("utf-8"))
    except (ValueError, json.JSONDecodeError) as error:
        raise BadRequestError("next_token is invalid") from error

    if not isinstance(value, dict):
        raise BadRequestError("next_token is invalid")

    return value


def require_non_empty_string(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise BadRequestError(f"{field_name} is required")
    return value.strip()


def optional_string(value: Any) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        raise BadRequestError("String field must be a string")
    return value.strip()


def normalize_string_list(value: Any, *, field_name: str) -> list[str]:
    if value is None:
        return []

    if not isinstance(value, list):
        raise BadRequestError(f"{field_name} must be an array of strings")

    normalized: list[str] = []
    seen: set[str] = set()
    for item in value:
        if not isinstance(item, str) or not item.strip():
            raise BadRequestError(f"{field_name} must contain only non-empty strings")
        cleaned = item.strip()
        if cleaned not in seen:
            seen.add(cleaned)
            normalized.append(cleaned)

    return normalized


def normalize_tag(value: str) -> str:
    normalized = value.strip().lower()
    if not normalized:
        raise BadRequestError("tag must not be empty")
    return normalized


def normalize_tags(value: Any) -> list[str]:
    tags = normalize_string_list(value, field_name="tags")
    normalized: list[str] = []
    seen: set[str] = set()

    for tag in tags:
        cleaned = normalize_tag(tag)
        if cleaned not in seen:
            seen.add(cleaned)
            normalized.append(cleaned)

    return normalized


def tag_index_id(tag: str, prompt_id: str) -> str:
    return f"PROMPT_TAG#{tag}#{prompt_id}"


def current_timestamp() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")