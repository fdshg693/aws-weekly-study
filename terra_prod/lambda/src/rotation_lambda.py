import json
import logging
import os
import secrets
import string
from datetime import datetime, timezone

import boto3


logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format='[%(levelname)s] %(message)s'
)

logger = logging.getLogger(__name__)
secrets_client = boto3.client("secretsmanager")
API_KEY_ALPHABET = string.ascii_letters + string.digits + "-_"


def _generate_api_key(length: int) -> str:
    return "".join(secrets.choice(API_KEY_ALPHABET) for _ in range(length))


def _build_secret_payload(length: int) -> str:
    payload = {
        "api_key": _generate_api_key(length),
        "rotated_at": datetime.now(timezone.utc).isoformat(),
    }
    return json.dumps(payload)


def _validate_secret(secret_arn: str, client_request_token: str):
    metadata = secrets_client.describe_secret(SecretId=secret_arn)
    versions = metadata.get("VersionIdsToStages", {})

    if client_request_token not in versions:
        raise ValueError("Secrets Manager rotation token is not registered on this secret")

    if "AWSCURRENT" in versions[client_request_token]:
        logger.info("Version %s is already current. Nothing to do.", client_request_token)
        return metadata, versions, True

    if "AWSPENDING" not in versions[client_request_token]:
        raise ValueError("Secrets Manager rotation token is not marked as AWSPENDING")

    return metadata, versions, False


def _create_secret(secret_arn: str, client_request_token: str, key_length: int):
    try:
        secrets_client.get_secret_value(
            SecretId=secret_arn,
            VersionId=client_request_token,
            VersionStage="AWSPENDING",
        )
        logger.info("AWSPENDING version already exists for token %s", client_request_token)
        return
    except secrets_client.exceptions.ResourceNotFoundException:
        pass

    secrets_client.put_secret_value(
        SecretId=secret_arn,
        ClientRequestToken=client_request_token,
        SecretString=_build_secret_payload(key_length),
        VersionStages=["AWSPENDING"],
    )
    logger.info("Created AWSPENDING secret version for token %s", client_request_token)


def _set_secret(secret_arn: str, client_request_token: str):
    # 外部システムへ反映する必要のない shared API key なので、
    # Secrets Manager 内の AWSPENDING バージョンが存在すれば十分。
    secrets_client.get_secret_value(
        SecretId=secret_arn,
        VersionId=client_request_token,
        VersionStage="AWSPENDING",
    )
    logger.info("setSecret step completed for token %s", client_request_token)


def _test_secret(secret_arn: str, client_request_token: str):
    pending_secret = secrets_client.get_secret_value(
        SecretId=secret_arn,
        VersionId=client_request_token,
        VersionStage="AWSPENDING",
    )

    payload = json.loads(pending_secret.get("SecretString", "{}"))
    api_key = str(payload.get("api_key", ""))
    if not api_key:
        raise ValueError("Pending secret does not contain api_key")

    logger.info("testSecret step completed for token %s", client_request_token)


def _finish_secret(secret_arn: str, client_request_token: str, versions: dict):
    current_version = None
    for version_id, stages in versions.items():
        if "AWSCURRENT" in stages:
            current_version = version_id
            break

    params = {
        "SecretId": secret_arn,
        "VersionStage": "AWSCURRENT",
        "MoveToVersionId": client_request_token,
    }
    if current_version:
        params["RemoveFromVersionId"] = current_version

    secrets_client.update_secret_version_stage(**params)
    logger.info("finishSecret step completed. Token %s is now AWSCURRENT", client_request_token)


def lambda_handler(event, context):
    secret_arn = event["SecretId"]
    client_request_token = event["ClientRequestToken"]
    step = event["Step"]

    expected_secret_arn = os.environ.get("API_KEY_SECRET_ARN", "")
    key_length = int(os.environ.get("API_KEY_LENGTH", "48"))

    if expected_secret_arn and secret_arn != expected_secret_arn:
        raise ValueError("Rotation request was received for an unexpected secret")

    _, versions, already_current = _validate_secret(secret_arn, client_request_token)
    if already_current:
        return

    if step == "createSecret":
        _create_secret(secret_arn, client_request_token, key_length)
    elif step == "setSecret":
        _set_secret(secret_arn, client_request_token)
    elif step == "testSecret":
        _test_secret(secret_arn, client_request_token)
    elif step == "finishSecret":
        _finish_secret(secret_arn, client_request_token, versions)
    else:
        raise ValueError(f"Unsupported rotation step: {step}")