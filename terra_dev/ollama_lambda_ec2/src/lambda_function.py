# pyright: reportMissingImports=false

"""Lambda proxy for the Ollama-on-EC2 sample project.

This function sits behind API Gateway HTTP API, validates a shared x-api-key header
against a value stored in AWS Secrets Manager, and then forwards the request to the
Ollama REST API running on EC2.
"""

from __future__ import annotations

import base64
import hmac
import json
import logging
import os
import socket
from typing import Any
from urllib import error, request
from urllib.parse import urlsplit

import boto3
from botocore.config import Config

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

SECRETS_CLIENT = boto3.client(
    "secretsmanager",
    config=Config(retries={"max_attempts": 2, "mode": "standard"}),
)
SECRET_CACHE: str | None = None

DEFAULT_MODEL = os.environ.get("DEFAULT_MODEL", "qwen2.5:0.5b")
OLLAMA_BASE_URL = os.environ["OLLAMA_BASE_URL"].rstrip("/")
SECRET_ARN = os.environ.get("SHARED_API_SECRET_ARN") or os.environ.get("SHARED_API_SECRET_NAME", "")
REQUEST_TIMEOUT_SECONDS = int(os.environ.get("OLLAMA_REQUEST_TIMEOUT_SECONDS", "25"))
JSON_HEADERS = {"content-type": "application/json; charset=utf-8"}


def _response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": JSON_HEADERS,
        "body": json.dumps(body, ensure_ascii=False),
    }


def _get_header(headers: dict[str, Any] | None, key: str) -> str:
    if not headers:
        return ""

    target = key.lower()
    for current_key, current_value in headers.items():
        if current_key.lower() == target:
            return str(current_value)
    return ""


def _decode_body(event: dict[str, Any]) -> str:
    body = event.get("body") or ""
    if not body:
        return ""

    if event.get("isBase64Encoded"):
        return base64.b64decode(body).decode("utf-8")
    return body


def _parse_request(event: dict[str, Any]) -> tuple[str, str]:
    raw_body = _decode_body(event)
    if not raw_body:
        raise ValueError("Request body must not be empty.")

    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError("Request body must be valid JSON.") from exc

    prompt = payload.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        raise ValueError("prompt must be a non-empty string.")

    requested_model = payload.get("model")
    if requested_model is None or requested_model == "":
        model = DEFAULT_MODEL
    elif isinstance(requested_model, str):
        model = requested_model.strip() or DEFAULT_MODEL
    else:
        raise ValueError("model must be a string when provided.")

    return prompt.strip(), model


def _load_shared_secret() -> str:
    global SECRET_CACHE

    if SECRET_CACHE is not None:
        return SECRET_CACHE

    if not SECRET_ARN:
        raise RuntimeError("SHARED_API_SECRET_ARN or SHARED_API_SECRET_NAME must be configured.")

    secret_value = SECRETS_CLIENT.get_secret_value(SecretId=SECRET_ARN)
    if "SecretString" in secret_value:
        SECRET_CACHE = secret_value["SecretString"]
    else:
        SECRET_CACHE = base64.b64decode(secret_value["SecretBinary"]).decode("utf-8")

    return SECRET_CACHE


def _forward_to_ollama(prompt: str, model: str, request_id: str) -> dict[str, Any]:
    target = urlsplit(OLLAMA_BASE_URL)
    target_host = target.hostname or "unknown"
    target_port = target.port or (443 if target.scheme == "https" else 80)

    try:
        resolved_targets = sorted({address[4][0] for address in socket.getaddrinfo(target_host, target_port, type=socket.SOCK_STREAM)})
    except OSError as exc:
        resolved_targets = [f"resolution_failed:{exc}"]

    LOGGER.info(
        "Forwarding request_id=%s to Ollama base_url=%s host=%s port=%s resolved_targets=%s model=%s prompt_chars=%s timeout_seconds=%s",
        request_id,
        OLLAMA_BASE_URL,
        target_host,
        target_port,
        resolved_targets,
        model,
        len(prompt),
        REQUEST_TIMEOUT_SECONDS,
    )

    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
    }).encode("utf-8")

    upstream_request = request.Request(
        url=f"{OLLAMA_BASE_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with request.urlopen(upstream_request, timeout=REQUEST_TIMEOUT_SECONDS) as upstream_response:
            upstream_payload = upstream_response.read().decode("utf-8")
    except error.HTTPError as exc:
        upstream_error = exc.read().decode("utf-8", errors="replace")
        LOGGER.warning(
            "Ollama returned HTTP %s for request_id=%s target=%s",
            exc.code,
            request_id,
            OLLAMA_BASE_URL,
        )
        return _response(
            502,
            {
                "message": "Upstream Ollama API returned an error.",
                "upstream_status": exc.code,
                "upstream_body": upstream_error[:1000],
            },
        )
    except error.URLError as exc:
        reason = exc.reason
        LOGGER.warning(
            "Failed connecting to Ollama for request_id=%s target=%s reason_type=%s reason=%r",
            request_id,
            OLLAMA_BASE_URL,
            type(reason).__name__,
            reason,
        )
        if isinstance(reason, socket.timeout):
            return _response(504, {"message": "Timed out while waiting for Ollama response."})
        return _response(502, {"message": f"Failed to connect to Ollama: {reason}"})
    except TimeoutError:
        LOGGER.warning("Timed out connecting to Ollama for request_id=%s target=%s", request_id, OLLAMA_BASE_URL)
        return _response(504, {"message": "Timed out while waiting for Ollama response."})
    except socket.timeout:
        LOGGER.warning("Socket timed out connecting to Ollama for request_id=%s target=%s", request_id, OLLAMA_BASE_URL)
        return _response(504, {"message": "Timed out while waiting for Ollama response."})

    LOGGER.info(
        "Received upstream response for request_id=%s target=%s payload_bytes=%s",
        request_id,
        OLLAMA_BASE_URL,
        len(upstream_payload.encode("utf-8")),
    )

    try:
        upstream_json = json.loads(upstream_payload)
    except json.JSONDecodeError:
        LOGGER.exception("Ollama returned non-JSON payload")
        return _response(502, {"message": "Ollama returned a non-JSON response."})

    return _response(
        200,
        {
            "model": upstream_json.get("model", model),
            "response": upstream_json.get("response", ""),
            "done": upstream_json.get("done", False),
            "done_reason": upstream_json.get("done_reason"),
            "context": upstream_json.get("context"),
            "total_duration": upstream_json.get("total_duration"),
            "load_duration": upstream_json.get("load_duration"),
            "eval_count": upstream_json.get("eval_count"),
            "eval_duration": upstream_json.get("eval_duration"),
        },
    )


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_id = getattr(context, "aws_request_id", "unknown")
    LOGGER.info("Handling request_id=%s", request_id)

    try:
        supplied_api_key = _get_header(event.get("headers"), "x-api-key")
        if not supplied_api_key:
            return _response(403, {"message": "x-api-key header is required."})

        expected_api_key = _load_shared_secret()
        if not hmac.compare_digest(supplied_api_key, expected_api_key):
            return _response(403, {"message": "Invalid API key."})

        prompt, model = _parse_request(event)
        return _forward_to_ollama(prompt=prompt, model=model, request_id=request_id)
    except ValueError as exc:
        return _response(400, {"message": str(exc)})
    except Exception:
        LOGGER.exception("Unhandled error while processing request_id=%s", request_id)
        return _response(500, {"message": "Internal server error."})
