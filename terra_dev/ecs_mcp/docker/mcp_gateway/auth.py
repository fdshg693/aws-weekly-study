from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import httpx

from .config import Settings
from .logging import get_logger

LOGGER = get_logger(__name__)


class AuthenticationError(Exception):
    """Raised when a request does not carry a valid access token."""


class AuthorizationError(Exception):
    """Raised when a valid token lacks required authorization."""


@dataclass(slots=True)
class AuthContext:
    subject: str | None
    client_id: str | None
    scopes: set[str]
    expires_at: int | None
    claims: dict[str, Any]


class KeycloakTokenIntrospector:
    """Validate Keycloak-issued bearer tokens via the introspection endpoint."""

    def __init__(self, settings: Settings, http_client: httpx.AsyncClient) -> None:
        self._settings = settings
        self._http_client = http_client
        self._cache: dict[str, tuple[float, AuthContext]] = {}

    async def authenticate(self, token: str) -> AuthContext:
        cached = self._get_cached(token)
        if cached is not None:
            return cached

        payload = {
            "token": token,
            "client_id": self._settings.oauth_introspection_client_id,
            "client_secret": self._settings.oauth_introspection_client_secret,
        }

        try:
            response = await self._http_client.post(
                self._settings.oauth_introspection_endpoint,
                data=payload,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            LOGGER.warning(
                "token introspection returned an unexpected status",
                extra={"status_code": exc.response.status_code},
            )
            raise AuthenticationError("Token validation failed") from exc
        except httpx.HTTPError as exc:
            LOGGER.exception("token introspection request failed")
            raise AuthenticationError("Token validation failed") from exc

        try:
            claims = response.json()
        except ValueError as exc:
            LOGGER.warning("token introspection returned non-JSON payload")
            raise AuthenticationError("Token validation failed") from exc

        if not claims.get("active"):
            raise AuthenticationError("Inactive token")

        self._validate_issuer(claims)
        scopes = self._extract_scopes(claims)
        self._validate_required_scopes(scopes)
        self._validate_audience(claims)

        auth_context = AuthContext(
            subject=claims.get("sub"),
            client_id=claims.get("client_id") or claims.get("azp"),
            scopes=scopes,
            expires_at=claims.get("exp"),
            claims=claims,
        )
        self._store_cache(token, auth_context)
        return auth_context

    def _validate_issuer(self, claims: dict[str, Any]) -> None:
        issuer = claims.get("iss")
        if issuer != self._settings.oauth_issuer:
            raise AuthenticationError("Unexpected token issuer")

    def _validate_required_scopes(self, scopes: set[str]) -> None:
        required_scopes = set(self._settings.oauth_required_scopes)
        if required_scopes and not required_scopes.issubset(scopes):
            missing_scopes = sorted(required_scopes - scopes)
            raise AuthorizationError(
                f"Missing required scopes: {' '.join(missing_scopes)}"
            )

    def _validate_audience(self, claims: dict[str, Any]) -> None:
        audience = claims.get("aud")
        audiences: set[str]
        if isinstance(audience, list):
            audiences = {str(item) for item in audience}
        elif isinstance(audience, str) and audience:
            audiences = {audience}
        else:
            audiences = set()

        expected = set(self._settings.oauth_expected_audiences)
        if expected and not audiences.intersection(expected):
            raise AuthenticationError("Token audience is not valid for this server")

    @staticmethod
    def _extract_scopes(claims: dict[str, Any]) -> set[str]:
        raw_scope = claims.get("scope", "")
        if isinstance(raw_scope, str):
            return {scope for scope in raw_scope.split() if scope}
        if isinstance(raw_scope, list):
            return {str(scope) for scope in raw_scope if str(scope)}
        return set()

    def _get_cached(self, token: str) -> AuthContext | None:
        cached = self._cache.get(token)
        if cached is None:
            return None

        expires_at, auth_context = cached
        if expires_at <= time.time():
            self._cache.pop(token, None)
            return None
        return auth_context

    def _store_cache(self, token: str, auth_context: AuthContext) -> None:
        expires_at = auth_context.expires_at or 0
        now = time.time()
        if expires_at <= now:
            return

        ttl = min(expires_at - now, 60)
        if ttl <= 0:
            return

        self._cache[token] = (now + ttl, auth_context)


def build_bearer_challenge(
    settings: Settings,
    *,
    error: str | None = None,
    scope: list[str] | None = None,
    error_description: str | None = None,
) -> str:
    """Build a RFC 6750 / RFC 9728 compatible challenge header."""

    params = [
        'realm="mcp"',
        f'resource_metadata="{settings.resource_metadata_url}"',
    ]

    scopes = scope if scope is not None else settings.oauth_required_scopes
    if scopes:
        params.append(f'scope="{" ".join(scopes)}"')
    if error:
        params.append(f'error="{error}"')
    if error_description:
        params.append(f'error_description="{error_description}"')

    return f"Bearer {', '.join(params)}"
