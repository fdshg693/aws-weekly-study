"""Bedrock-backed Lambda handler for API Gateway HTTP API."""

import base64
import json
import logging
import os
import sys
from datetime import datetime, timezone

import boto3
from botocore.exceptions import BotoCoreError, ClientError


logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format='[%(levelname)s] %(message)s',
    stream=sys.stderr,
)

logger = logging.getLogger(__name__)
bedrock_runtime = boto3.client("bedrock-runtime")


def _response(status_code, payload):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,x-api-key",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
        },
        "body": json.dumps(payload, ensure_ascii=False),
    }


def _extract_request_payload(event):
    if not isinstance(event, dict):
        return {}, {}

    payload = {}
    request_meta = {
        "source": "direct-invoke",
        "raw_path": event.get("rawPath"),
        "request_context": event.get("requestContext", {}),
        "method": ((event.get("requestContext") or {}).get("http") or {}).get("method", "GET"),
    }

    query_params = event.get("queryStringParameters") or {}
    if isinstance(query_params, dict):
        payload.update(query_params)

    body = event.get("body")
    if body:
        request_meta["source"] = "api-gateway"
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")

        try:
            parsed_body = json.loads(body)
            if isinstance(parsed_body, dict):
                payload.update(parsed_body)
            else:
                payload["body"] = parsed_body
        except json.JSONDecodeError:
            payload["body"] = body
    elif "requestContext" in event:
        request_meta["source"] = "api-gateway"

    return payload, request_meta


def _extract_text_from_converse_response(response):
    content = (
        response.get("output", {})
        .get("message", {})
        .get("content", [])
    )
    return "\n".join(
        item.get("text", "")
        for item in content
        if isinstance(item, dict) and item.get("text")
    ).strip()


def _health_payload(context):
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "request_id": context.aws_request_id,
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "app_name": os.environ.get("APP_NAME", "lambda-function"),
        "model_id": os.environ.get("BEDROCK_MODEL_ID", "unknown"),
    }


def lambda_handler(event, context):
    environment = os.environ.get("ENVIRONMENT", "unknown")
    app_name = os.environ.get("APP_NAME", "lambda-function")
    model_id = os.environ.get("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")
    max_tokens = int(os.environ.get("BEDROCK_MAX_TOKENS", "256"))
    temperature = float(os.environ.get("BEDROCK_TEMPERATURE", "0.5"))

    logger.info("Lambda invoked in %s for app %s", environment, app_name)
    logger.info("Request ID: %s", context.aws_request_id)
    logger.debug("Received event: %s", json.dumps(event, ensure_ascii=False))

    request_payload, request_meta = _extract_request_payload(event)
    method = request_meta.get("method", "GET").upper()

    if method == "GET":
        return _response(200, _health_payload(context))

    prompt = str(request_payload.get("prompt") or request_payload.get("message") or "").strip()
    if not prompt:
        return _response(
            400,
            {
                "error": "prompt is required",
                "request_id": context.aws_request_id,
            },
        )

    try:
        bedrock_response = bedrock_runtime.converse(
            modelId=model_id,
            messages=[
                {
                    "role": "user",
                    "content": [{"text": prompt}],
                }
            ],
            inferenceConfig={
                "maxTokens": max_tokens,
                "temperature": temperature,
            },
        )
    except (ClientError, BotoCoreError) as exc:
        logger.exception("Failed to invoke Bedrock model: %s", exc)
        return _response(
            502,
            {
                "error": "Failed to invoke Bedrock",
                "details": str(exc),
                "request_id": context.aws_request_id,
                "model_id": model_id,
            },
        )

    output_text = _extract_text_from_converse_response(bedrock_response)
    response_data = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": environment,
        "app_name": app_name,
        "request_id": context.aws_request_id,
        "model_id": model_id,
        "prompt": prompt,
        "output_text": output_text,
        "stop_reason": bedrock_response.get("stopReason"),
        "usage": bedrock_response.get("usage", {}),
        "bedrock_request_id": ((bedrock_response.get("ResponseMetadata") or {}).get("RequestId")),
        "request": request_meta,
    }

    logger.info("Bedrock response prepared successfully")
    return _response(200, response_data)