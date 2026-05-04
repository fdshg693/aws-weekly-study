#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


RECORD_PATTERN = re.compile(r"(REQUEST_SUMMARY|RESPONSE_SUMMARY|ERROR_SUMMARY)\s+(\{.*\})$")
SUPPORTED_METHODS = {"POST", "GET", "ALL"}
SUPPORTED_RECORD_TYPES = {"request_summary", "response_summary", "error_summary"}
THROTTLING_ERROR_CODES = {"ThrottlingException", "TooManyRequestsException"}
MAX_TOKEN_STOP_REASONS = {"max_tokens", "maxtokens"}


@dataclass(frozen=True)
class Config:
    start_time: str
    end_time: str
    since: str
    method: str
    log_group_name: str
    aws_region: str
    script_dir: Path


def env_or_default(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="CloudWatch Logs 上の Lambda 要約ログを集計します。",
    )
    parser.add_argument("--start-time", default=env_or_default("START_TIME"), help="集計開始時刻 (ISO 8601)")
    parser.add_argument("--end-time", default=env_or_default("END_TIME"), help="集計終了時刻 (ISO 8601, 省略時は現在時刻)")
    parser.add_argument("--since", default=env_or_default("SINCE", "1h"), help="相対期間。START_TIME 未指定時のみ使用 (例: 15m, 1h, 2d)")
    parser.add_argument(
        "--method",
        default=env_or_default("METHOD", "POST").upper(),
        help="POST / GET / ALL。既定: POST",
    )
    parser.add_argument(
        "--log-group-name",
        default=env_or_default("LOG_GROUP_NAME"),
        help="CloudWatch Logs グループ名。省略時は terraform output log_group_name を使用",
    )
    parser.add_argument(
        "--aws-region",
        default=env_or_default("AWS_REGION"),
        help="AWS リージョン。省略時は terraform output deployment_summary.region を使用",
    )
    return parser


def require_command(command_name: str, message: str) -> None:
    if shutil.which(command_name):
        return
    raise SystemExit(message)


def run_command(command: list[str], cwd: Path) -> str:
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd),
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or exc.stdout or "").strip()
        raise RuntimeError(stderr or f"command failed: {' '.join(command)}") from exc

    return completed.stdout.strip()


def terraform_output_raw(output_name: str, cwd: Path) -> str:
    try:
        return run_command(["terraform", "output", "-raw", output_name], cwd)
    except RuntimeError:
        return ""


def terraform_output_json_field(output_name: str, field_name: str, cwd: Path) -> str:
    try:
        output = run_command(["terraform", "output", "-json", output_name], cwd)
    except RuntimeError:
        return ""

    if not output:
        return ""

    try:
        payload = json.loads(output)
    except json.JSONDecodeError:
        return ""

    value = payload.get(field_name)
    return "" if value is None else str(value).strip()


def parse_iso8601(value: str) -> datetime:
    normalized = value.strip()
    if not normalized:
        raise ValueError("empty datetime")
    normalized = normalized.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def parse_since(value: str) -> timedelta:
    match = re.fullmatch(r"(\d+)([smhdw])", value.strip())
    if not match:
        raise ValueError("SINCE は 15m / 1h / 2d のように指定してください。")

    amount = int(match.group(1))
    unit = match.group(2)
    seconds_per_unit = {
        "s": 1,
        "m": 60,
        "h": 60 * 60,
        "d": 60 * 60 * 24,
        "w": 60 * 60 * 24 * 7,
    }
    return timedelta(seconds=amount * seconds_per_unit[unit])


def resolve_time_range(start_time: str, end_time: str, since: str) -> tuple[int, int, str, str]:
    now = datetime.now(timezone.utc)

    if start_time:
        start_dt = parse_iso8601(start_time)
    else:
        end_anchor = parse_iso8601(end_time) if end_time else now
        start_dt = end_anchor - parse_since(since)

    end_dt = parse_iso8601(end_time) if end_time else now

    if start_dt >= end_dt:
        raise ValueError("START_TIME は END_TIME より前である必要があります。")

    return (
        int(start_dt.timestamp() * 1000),
        int(end_dt.timestamp() * 1000),
        start_dt.isoformat().replace("+00:00", "Z"),
        end_dt.isoformat().replace("+00:00", "Z"),
    )


def parse_args(script_dir: Path) -> Config:
    args = build_parser().parse_args()
    method = args.method.upper()
    if method not in SUPPORTED_METHODS:
        raise SystemExit("METHOD は POST / GET / ALL のいずれかを指定してください。")

    if (not args.log_group_name or not args.aws_region):
        require_command(
            "terraform",
            "terraform が見つかりません。LOG_GROUP_NAME / AWS_REGION を明示するか Terraform をインストールしてください。",
        )

    log_group_name = args.log_group_name or terraform_output_raw("log_group_name", script_dir)
    aws_region = args.aws_region or terraform_output_json_field("deployment_summary", "region", script_dir)

    if not log_group_name:
        raise SystemExit("CloudWatch Logs グループ名を取得できませんでした。LOG_GROUP_NAME を指定してください。")
    if not aws_region:
        raise SystemExit("AWS リージョンを取得できませんでした。AWS_REGION を指定してください。")

    return Config(
        start_time=args.start_time,
        end_time=args.end_time,
        since=args.since,
        method=method,
        log_group_name=log_group_name,
        aws_region=aws_region,
        script_dir=script_dir,
    )


def fetch_log_events(config: Config, start_ms: int, end_ms: int) -> list[dict[str, Any]]:
    output = run_command(
        [
            "aws",
            "logs",
            "filter-log-events",
            "--log-group-name",
            config.log_group_name,
            "--region",
            config.aws_region,
            "--start-time",
            str(start_ms),
            "--end-time",
            str(end_ms),
            "--output",
            "json",
        ],
        config.script_dir,
    )

    try:
        payload = json.loads(output)
    except json.JSONDecodeError as exc:
        raise RuntimeError("aws logs filter-log-events の出力 JSON を解析できませんでした。") from exc

    events = payload.get("events")
    return events if isinstance(events, list) else []


def parse_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []

    for event in events:
        message = str(event.get("message", ""))
        match = RECORD_PATTERN.search(message)
        if not match:
            continue

        try:
            payload = json.loads(match.group(2))
        except json.JSONDecodeError:
            continue

        if not isinstance(payload, dict):
            continue

        record_type = str(payload.get("record_type", "")).strip()
        if record_type not in SUPPORTED_RECORD_TYPES:
            continue

        records.append(payload)

    return records


def request_ids(records: list[dict[str, Any]]) -> list[str]:
    return sorted({str(record.get("request_id", "")).strip() for record in records if str(record.get("request_id", "")).strip()})


def summarize_records(records: list[dict[str, Any]], method: str) -> dict[str, Any]:
    filtered = [record for record in records if method == "ALL" or str(record.get("method", "")).upper() == method]
    requests = [record for record in filtered if record.get("record_type") == "request_summary"]
    responses = [record for record in filtered if record.get("record_type") == "response_summary"]
    errors = [record for record in filtered if record.get("record_type") == "error_summary"]
    success_responses = [record for record in responses if int(record.get("status_code", 200)) < 400]
    throttling_errors = [
        record
        for record in errors
        if int(record.get("status_code", 0)) == 429 or str(record.get("error_code", "")) in THROTTLING_ERROR_CODES
    ]
    max_token_stops = [
        record
        for record in responses
        if str(record.get("stop_reason", "")).lower().replace("_", "") in MAX_TOKEN_STOP_REASONS
    ]

    error_code_breakdown: list[dict[str, Any]] = []
    error_groups: dict[str, list[dict[str, Any]]] = {}
    for record in errors:
        error_code = str(record.get("error_code") or "Unknown")
        error_groups.setdefault(error_code, []).append(record)

    for error_code, grouped_records in sorted(error_groups.items(), key=lambda item: (-len(request_ids(item[1])), item[0])):
        error_code_breakdown.append({
            "error_code": error_code,
            "count": len(request_ids(grouped_records)),
        })

    return {
        "method": method,
        "total_requests": len(request_ids(requests + responses + errors)),
        "request_summary_count": len(request_ids(requests)),
        "success_count": len(request_ids(success_responses)),
        "error_count": len(request_ids(errors)),
        "throttling_error_count": len(request_ids(throttling_errors)),
        "max_token_stop_count": len(request_ids(max_token_stops)),
        "throttling_request_ids": request_ids(throttling_errors)[:5],
        "max_token_request_ids": request_ids(max_token_stops)[:5],
        "error_code_breakdown": error_code_breakdown,
    }


def percent(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "0.0"
    return f"{(numerator / denominator) * 100:.1f}"


def print_summary(summary: dict[str, Any], config: Config, start_iso: str, end_iso: str) -> None:
    total_requests = int(summary["total_requests"])
    success_count = int(summary["success_count"])
    error_count = int(summary["error_count"])
    throttling_error_count = int(summary["throttling_error_count"])
    max_token_stop_count = int(summary["max_token_stop_count"])
    other_error_count = max(error_count - throttling_error_count, 0)

    print("==> Lambda request log analysis")
    print(f"Log group: {config.log_group_name}")
    print(f"Region: {config.aws_region}")
    print(f"Range: {start_iso} .. {end_iso}")
    print(f"Method filter: {config.method}")
    print()
    print(f"Total requests: {total_requests}")
    print(f"Successful responses: {success_count}")
    print(f"Error responses: {error_count} ({percent(error_count, total_requests)}%)")
    print(f"  - Throttling errors: {throttling_error_count} ({percent(throttling_error_count, total_requests)}%)")
    print(f"  - Other errors: {other_error_count}")
    print(f"Responses stopped by max tokens: {max_token_stop_count} ({percent(max_token_stop_count, total_requests)}%)")

    throttling_request_ids = summary["throttling_request_ids"]
    if throttling_request_ids:
        print("\nSample throttling request IDs:")
        for request_id in throttling_request_ids:
            print(f"  - {request_id}")

    max_token_request_ids = summary["max_token_request_ids"]
    if max_token_request_ids:
        print("\nSample max_tokens request IDs:")
        for request_id in max_token_request_ids:
            print(f"  - {request_id}")

    error_code_breakdown = summary["error_code_breakdown"]
    if error_code_breakdown:
        print("\nError code breakdown:")
        for item in error_code_breakdown:
            print(f"  - {item['error_code']}: {item['count']}")


def main() -> int:
    script_dir = Path(__file__).resolve().parent

    require_command("aws", "aws CLI が見つかりません。")

    try:
        config = parse_args(script_dir)
        start_ms, end_ms, start_iso, end_iso = resolve_time_range(
            start_time=config.start_time,
            end_time=config.end_time,
            since=config.since,
        )
        records = parse_records(fetch_log_events(config, start_ms, end_ms))
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except SystemExit as exc:
        raise exc

    if not records:
        print("指定範囲内に解析対象の要約ログが見つかりませんでした。terraform apply 後のログ範囲を確認してください。")
        return 0

    summary = summarize_records(records, config.method)
    print_summary(summary, config, start_iso, end_iso)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())