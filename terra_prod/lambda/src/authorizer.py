import json
import logging
import os
import secrets

import boto3


logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format='[%(levelname)s] %(message)s'
)

logger = logging.getLogger(__name__)
secrets_client = boto3.client("secretsmanager")


def _extract_api_key_value(secret_string: str) -> str:
    try:
        payload = json.loads(secret_string)
        if isinstance(payload, dict):
            value = payload.get("api_key") or payload.get("value") or ""
            return str(value).strip()
    except json.JSONDecodeError:
        pass

    return secret_string.strip()


def _get_header(headers: dict, header_name: str) -> str:
    if not isinstance(headers, dict):
        return ""

    for key, value in headers.items():
        if str(key).lower() == header_name.lower():
            return str(value).strip()

    return ""


def lambda_handler(event, context):
    secret_arn = os.environ.get("API_KEY_SECRET_ARN", "")
    provided_api_key = _get_header(event.get("headers") or {}, "x-api-key")

    if not secret_arn:
        logger.error("API_KEY_SECRET_ARN is not configured")
        return {"isAuthorized": False}

    if not provided_api_key:
        logger.info("Request denied: x-api-key header is missing")
        return {"isAuthorized": False}

    try:
        secret_value = secrets_client.get_secret_value(SecretId=secret_arn)
        expected_api_key = _extract_api_key_value(secret_value.get("SecretString", ""))
    except Exception as exc:  # noqa: BLE001
        logger.exception("Failed to load API key secret: %s", exc)
        return {"isAuthorized": False}

    is_authorized = bool(expected_api_key) and secrets.compare_digest(
        provided_api_key,
        expected_api_key,
    )

    if not is_authorized:
        logger.info("Request denied: x-api-key did not match current secret")
        return {"isAuthorized": False}

    logger.info("Request authorized successfully")
    return {
        "isAuthorized": True,
        "context": {
            "secretArn": secret_arn,
            "authorizerRequestId": context.aws_request_id,
        },
    }