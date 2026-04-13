from __future__ import annotations

import json
from functools import cached_property
from typing import Any
from urllib.parse import urlsplit, urlunsplit

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the MCP HTTP gateway."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "info"
    public_base_url: str = "https://localhost"
    mcp_path: str = "/mcp"
    mcp_stateless_http: bool = True

    oauth_issuer: str = ""
    oauth_authorization_endpoint: str = ""
    oauth_token_endpoint: str = ""
    oauth_registration_endpoint: str = ""
    oauth_public_client_id: str = ""
    oauth_introspection_endpoint: str = ""
    oauth_introspection_client_id: str = ""
    oauth_introspection_client_secret: str = Field(default="", repr=False)
    oauth_supported_scopes: list[str] = Field(default_factory=lambda: ["mcp:tools"])
    oauth_required_scopes: list[str] = Field(default_factory=lambda: ["mcp:tools"])
    oauth_expected_audiences: list[str] = Field(default_factory=list)
    oauth_introspection_timeout_seconds: float = 5.0

    @field_validator("public_base_url")
    @classmethod
    def validate_public_base_url(cls, value: str) -> str:
        return cls._normalize_base_url(value)

    @field_validator("mcp_path")
    @classmethod
    def validate_mcp_path(cls, value: str) -> str:
        path = value.strip() or "/mcp"
        if not path.startswith("/"):
            path = f"/{path}"
        return path.rstrip("/") or "/"

    @field_validator(
        "oauth_supported_scopes",
        "oauth_required_scopes",
        "oauth_expected_audiences",
        mode="before",
    )
    @classmethod
    def parse_list_value(cls, value: Any) -> list[str]:
        if value is None or value == "":
            return []

        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]

        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []

            if stripped.startswith("["):
                parsed = json.loads(stripped)
                if not isinstance(parsed, list):
                    msg = "Expected a JSON array"
                    raise ValueError(msg)
                return [str(item).strip() for item in parsed if str(item).strip()]

            separators = [",", " "]
            items = [stripped]
            for separator in separators:
                if separator in stripped:
                    items = stripped.replace(",", " ").split()
                    break
            return [item.strip() for item in items if item.strip()]

        msg = "Expected a list, JSON array, comma-separated string, or space-separated string"
        raise TypeError(msg)

    @model_validator(mode="after")
    def validate_oauth_settings(self) -> "Settings":
        if self.oauth_enabled:
            required_values = {
                "oauth_issuer": self.oauth_issuer,
                "oauth_authorization_endpoint": self.oauth_authorization_endpoint,
                "oauth_token_endpoint": self.oauth_token_endpoint,
                "oauth_introspection_endpoint": self.oauth_introspection_endpoint,
                "oauth_introspection_client_id": self.oauth_introspection_client_id,
                "oauth_introspection_client_secret": self.oauth_introspection_client_secret,
            }
            missing = [name for name, value in required_values.items() if not value]
            if missing:
                msg = f"OAuth is enabled but the following settings are missing: {', '.join(missing)}"
                raise ValueError(msg)

            if not self.oauth_expected_audiences:
                self.oauth_expected_audiences = [self.resource_server_url]

        return self

    @property
    def oauth_enabled(self) -> bool:
        return bool(self.oauth_issuer)

    @cached_property
    def resource_server_url(self) -> str:
        if self.mcp_path == "/":
            return self.public_base_url
        return f"{self.public_base_url}{self.mcp_path}"

    @cached_property
    def resource_metadata_url(self) -> str:
        return f"{self.public_base_url}/.well-known/oauth-protected-resource"

    @cached_property
    def authorization_server_metadata_url(self) -> str:
        return f"{self.public_base_url}/.well-known/oauth-authorization-server"

    @staticmethod
    def _normalize_base_url(value: str) -> str:
        normalized = value.strip().rstrip("/")
        parsed = urlsplit(normalized)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            msg = "public_base_url must be an absolute http/https URL"
            raise ValueError(msg)
        return urlunsplit((parsed.scheme.lower(), parsed.netloc.lower(), parsed.path.rstrip("/"), "", ""))
