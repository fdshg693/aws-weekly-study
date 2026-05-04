"""Bedrock-backed Lambda handler for API Gateway HTTP API."""

import base64
import json
import logging
import os
import sys
import time
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
LOG_TEXT_PREVIEW_LENGTH = 10

BEDROCK_ERROR_STATUS_CODES = {
    "AccessDeniedException": 403,
    "ResourceNotFoundException": 404,
    "ThrottlingException": 429,
    "TooManyRequestsException": 429,
    "ValidationException": 400,
    "ServiceUnavailableException": 503,
    "ModelNotReadyException": 503,
    "ModelTimeoutException": 504,
    "InternalServerException": 502,
}

RETRYABLE_BEDROCK_ERROR_CODES = {
    "ModelNotReadyException",
    "ModelTimeoutException",
    "ServiceUnavailableException",
    "ThrottlingException",
    "TooManyRequestsException",
}

RETRYABLE_BEDROCK_STATUS_CODES = {429, 502, 503, 504}
BEDROCK_RETRY_WAIT_SECONDS = 5
BEDROCK_MAX_RETRIES = 1


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


def _summarize_text_for_log(text, preview_length=LOG_TEXT_PREVIEW_LENGTH):
    normalized_text = "" if text is None else str(text)
    return {
        "preview": normalized_text[:preview_length],
        "length": len(normalized_text),
    }


def _log_structured_event(record_type, **payload):
    logger.info(
        "%s %s",
        record_type.upper(),
        json.dumps(
            {
                "record_type": record_type,
                **payload,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
    )


def _build_log_context(context, request_meta, method):
    return {
        "request_id": context.aws_request_id,
        "method": method,
        "source": request_meta.get("source"),
        "raw_path": request_meta.get("raw_path"),
    }


def _log_request_summary(context, request_meta, method, prompt):
    prompt_summary = _summarize_text_for_log(prompt)
    _log_structured_event(
        "request_summary",
        **_build_log_context(context, request_meta, method),
        prompt_preview=prompt_summary["preview"],
        prompt_length=prompt_summary["length"],
    )


def _log_response_summary(
    context,
    request_meta,
    method,
    status_code,
    model_id,
    output_text,
    stop_reason=None,
    retry_count=0,
    usage=None,
    bedrock_request_id=None,
):
    output_summary = _summarize_text_for_log(output_text)
    _log_structured_event(
        "response_summary",
        **_build_log_context(context, request_meta, method),
        status_code=status_code,
        model_id=model_id,
        output_preview=output_summary["preview"],
        output_length=output_summary["length"],
        stop_reason=stop_reason,
        usage=usage or {},
        bedrock_request_id=bedrock_request_id,
        retry_count=retry_count,
    )


def _log_error_summary(
    context,
    request_meta,
    method,
    status_code,
    error_type,
    error_code,
    error_message,
    model_id,
    retryable=False,
    upstream_status_code=None,
    bedrock_request_id=None,
):
    error_summary = _summarize_text_for_log(error_message)
    _log_structured_event(
        "error_summary",
        **_build_log_context(context, request_meta, method),
        status_code=status_code,
        error_type=error_type,
        error_code=error_code,
        error_message_preview=error_summary["preview"],
        error_message_length=error_summary["length"],
        model_id=model_id,
        retryable=retryable,
        upstream_status_code=upstream_status_code,
        bedrock_request_id=bedrock_request_id,
    )


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


def _extract_bedrock_error_details(exc, context, model_id):
    error_response = getattr(exc, "response", {}) or {}
    error = error_response.get("Error", {}) or {}
    metadata = error_response.get("ResponseMetadata", {}) or {}

    error_code = error.get("Code") or exc.__class__.__name__
    error_message = error.get("Message") or str(exc)
    upstream_status_code = metadata.get("HTTPStatusCode")

    if isinstance(upstream_status_code, int) and 400 <= upstream_status_code <= 599:
        status_code = upstream_status_code
    else:
        status_code = BEDROCK_ERROR_STATUS_CODES.get(error_code, 502)

    retryable = error_code in RETRYABLE_BEDROCK_ERROR_CODES or status_code in {429, 502, 503, 504}

    return {
        "status_code": status_code,
        "error_code": error_code,
        "error_message": error_message,
        "upstream_status_code": upstream_status_code,
        "retryable": retryable,
        "bedrock_request_id": metadata.get("RequestId"),
        "response_payload": {
            "error": "Bedrock request failed",
            "bedrock_error_code": error_code,
            "bedrock_error_message": error_message,
            "upstream_status_code": upstream_status_code,
            "retryable": retryable,
            "request_id": context.aws_request_id,
            "bedrock_request_id": metadata.get("RequestId"),
            "model_id": model_id,
        },
    }


def _build_bedrock_error_response(exc, context, model_id):
    error_details = _extract_bedrock_error_details(exc, context, model_id)
    return _response(error_details["status_code"], error_details["response_payload"]), error_details


def _is_retryable_client_error(exc):
    error_response = getattr(exc, "response", {}) or {}
    error = error_response.get("Error", {}) or {}
    metadata = error_response.get("ResponseMetadata", {}) or {}

    error_code = error.get("Code") or exc.__class__.__name__
    upstream_status_code = metadata.get("HTTPStatusCode")

    return (
        error_code in RETRYABLE_BEDROCK_ERROR_CODES
        or upstream_status_code in RETRYABLE_BEDROCK_STATUS_CODES
    )


def _has_retry_time_remaining(context):
    remaining_millis = getattr(context, "get_remaining_time_in_millis", lambda: 0)()
    return remaining_millis >= ((BEDROCK_RETRY_WAIT_SECONDS + 1) * 1000)


def _invoke_bedrock_with_retry(model_id, prompt, max_tokens, temperature, context):
    last_exception = None

    for attempt in range(BEDROCK_MAX_RETRIES + 1):
        try:
            response = bedrock_runtime.converse(
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
            return response, attempt
        except ClientError as exc:
            last_exception = exc
            should_retry = attempt < BEDROCK_MAX_RETRIES and _is_retryable_client_error(exc) and _has_retry_time_remaining(context)
            if not should_retry:
                raise

            logger.warning(
                "Retryable Bedrock client error detected (%s). Waiting %s seconds before retry %s/%s.",
                exc,
                BEDROCK_RETRY_WAIT_SECONDS,
                attempt + 1,
                BEDROCK_MAX_RETRIES,
            )
            time.sleep(BEDROCK_RETRY_WAIT_SECONDS)
        except BotoCoreError as exc:
            last_exception = exc
            should_retry = attempt < BEDROCK_MAX_RETRIES and _has_retry_time_remaining(context)
            if not should_retry:
                raise

            logger.warning(
                "Retryable Bedrock SDK error detected (%s). Waiting %s seconds before retry %s/%s.",
                exc,
                BEDROCK_RETRY_WAIT_SECONDS,
                attempt + 1,
                BEDROCK_MAX_RETRIES,
            )
            time.sleep(BEDROCK_RETRY_WAIT_SECONDS)

    raise last_exception


def lambda_handler(event, context):
    environment = os.environ.get("ENVIRONMENT", "unknown")
    app_name = os.environ.get("APP_NAME", "lambda-function")
    model_id = os.environ.get("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")
    max_tokens = int(os.environ.get("BEDROCK_MAX_TOKENS", "256"))
    temperature = float(os.environ.get("BEDROCK_TEMPERATURE", "0.5"))

    logger.info("Lambda invoked in %s for app %s", environment, app_name)
    logger.info("Request ID: %s", context.aws_request_id)

    request_payload, request_meta = _extract_request_payload(event)
    method = request_meta.get("method", "GET").upper()
    prompt = str(request_payload.get("prompt") or request_payload.get("message") or "").strip()

    _log_request_summary(
        context=context,
        request_meta=request_meta,
        method=method,
        prompt=prompt,
    )

    if method == "GET":
        health_payload = _health_payload(context)
        _log_response_summary(
            context=context,
            request_meta=request_meta,
            method=method,
            status_code=200,
            model_id=model_id,
            output_text="",
        )
        return _response(200, health_payload)

    if not prompt:
        _log_error_summary(
            context=context,
            request_meta=request_meta,
            method=method,
            status_code=400,
            error_type="validation_error",
            error_code="MissingPrompt",
            error_message="prompt is required",
            model_id=model_id,
        )
        return _response(
            400,
            {
                "error": "prompt is required",
                "request_id": context.aws_request_id,
            },
        )

    try:
        bedrock_response, retry_count = _invoke_bedrock_with_retry(
            model_id=model_id,
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            context=context,
        )
    except ClientError as exc:
        logger.exception("Bedrock returned a client error: %s", exc)
        error_response, error_details = _build_bedrock_error_response(exc, context, model_id)
        _log_error_summary(
            context=context,
            request_meta=request_meta,
            method=method,
            status_code=error_details["status_code"],
            error_type="bedrock_client_error",
            error_code=error_details["error_code"],
            error_message=error_details["error_message"],
            model_id=model_id,
            retryable=error_details["retryable"],
            upstream_status_code=error_details["upstream_status_code"],
            bedrock_request_id=error_details["bedrock_request_id"],
        )
        return error_response
    except BotoCoreError as exc:
        logger.exception("Failed to invoke Bedrock model: %s", exc)
        _log_error_summary(
            context=context,
            request_meta=request_meta,
            method=method,
            status_code=502,
            error_type="bedrock_sdk_error",
            error_code=exc.__class__.__name__,
            error_message=str(exc),
            model_id=model_id,
            retryable=True,
        )
        return _response(
            502,
            {
                "error": "Failed to invoke Bedrock",
                "bedrock_error_code": exc.__class__.__name__,
                "bedrock_error_message": str(exc),
                "request_id": context.aws_request_id,
                "model_id": model_id,
                "retryable": True,
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
        "retry_count": retry_count,
        "request": request_meta,
    }

    _log_response_summary(
        context=context,
        request_meta=request_meta,
        method=method,
        status_code=200,
        model_id=model_id,
        output_text=output_text,
        stop_reason=bedrock_response.get("stopReason"),
        retry_count=retry_count,
        usage=bedrock_response.get("usage", {}),
        bedrock_request_id=((bedrock_response.get("ResponseMetadata") or {}).get("RequestId")),
    )
    logger.info("Bedrock response prepared successfully")
    return _response(200, response_data)