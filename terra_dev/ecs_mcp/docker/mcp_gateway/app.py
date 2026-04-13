from __future__ import annotations

from contextlib import asynccontextmanager
from typing import Any

import httpx
from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.routing import Mount, Route
from starlette.types import ASGIApp, Receive, Scope, Send

from .auth import (
    AuthenticationError,
    AuthorizationError,
    KeycloakTokenIntrospector,
    build_bearer_challenge,
)
from .config import Settings
from .logging import configure_logging, get_logger

LOGGER = get_logger(__name__)


def create_application(*, mcp_app: ASGIApp, settings: Settings) -> Starlette:
    """Create the ASGI application that fronts the FastMCP server."""

    configure_logging(settings.log_level)

    @asynccontextmanager
    async def lifespan(_app: Starlette):
        timeout = httpx.Timeout(settings.oauth_introspection_timeout_seconds)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=False) as client:
            if settings.oauth_enabled:
                _app.state.token_introspector = KeycloakTokenIntrospector(settings, client)
            else:
                _app.state.token_introspector = None
            yield

    app = Starlette(
        debug=False,
        lifespan=lifespan,
        middleware=[Middleware(OAuthMiddleware)],
        routes=[
            Route("/health", endpoint=healthcheck, methods=["GET"]),
            Route(
                "/.well-known/oauth-protected-resource",
                endpoint=protected_resource_metadata,
                methods=["GET"],
            ),
            Route(
                "/.well-known/oauth-authorization-server",
                endpoint=authorization_server_metadata,
                methods=["GET"],
            ),
            Route("/oauth/register", endpoint=oauth_register, methods=["POST"]),
            Mount(settings.mcp_path, app=mcp_app),
        ],
    )

    app.state.settings = settings
    return app


async def healthcheck(request: Request) -> JSONResponse:
    settings = request.app.state.settings
    return JSONResponse(
        {
            "status": "ok",
            "service": "fastmcp",
            "mcp_path": settings.mcp_path,
            "stateless_http": settings.mcp_stateless_http,
            "oauth_enabled": settings.oauth_enabled,
        }
    )


async def protected_resource_metadata(request: Request) -> JSONResponse:
    settings = request.app.state.settings
    return JSONResponse(
        {
            "resource": settings.resource_server_url,
            "authorization_servers": [settings.public_base_url],
            "scopes_supported": settings.oauth_supported_scopes,
            "bearer_methods_supported": ["header"],
        }
    )


async def authorization_server_metadata(request: Request) -> JSONResponse:
    settings = request.app.state.settings
    payload: dict[str, Any] = {
        "issuer": settings.oauth_issuer,
        "authorization_endpoint": settings.oauth_authorization_endpoint,
        "token_endpoint": settings.oauth_token_endpoint,
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "token_endpoint_auth_methods_supported": ["none"],
        "code_challenge_methods_supported": ["S256"],
        "scopes_supported": settings.oauth_supported_scopes,
    }

    if settings.oauth_registration_endpoint:
        payload["registration_endpoint"] = settings.oauth_registration_endpoint
    elif settings.oauth_public_client_id:
        payload["registration_endpoint"] = f"{settings.public_base_url}/oauth/register"

    return JSONResponse(payload)


async def oauth_register(request: Request) -> JSONResponse:
    settings = request.app.state.settings
    if settings.oauth_registration_endpoint or not settings.oauth_public_client_id:
        return JSONResponse({"error": "dynamic client registration is not available"}, status_code=404)

    return JSONResponse(
        {
            "client_id": settings.oauth_public_client_id,
            "client_name": "Pre-registered MCP client",
            "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
        }
    )


class OAuthMiddleware:
    """Protect the mounted MCP transport with per-request bearer validation."""

    def __init__(self, app: Starlette) -> None:
        self._app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        settings: Settings = self._app.state.settings
        path = scope.get("path", "")

        if not settings.oauth_enabled or self._is_public_path(path, settings):
            await self._app(scope, receive, send)
            return

        if not self._targets_mcp_path(path, settings):
            await self._app(scope, receive, send)
            return

        try:
            auth_context = await self._authenticate(scope)
            scope.setdefault("state", {})["auth_context"] = auth_context
        except AuthenticationError:
            await self._send_response(
                scope,
                receive,
                send,
                status_code=401,
                headers={
                    "WWW-Authenticate": build_bearer_challenge(
                        settings,
                        error="invalid_token",
                    )
                },
            )
            return
        except AuthorizationError:
            await self._send_response(
                scope,
                receive,
                send,
                status_code=403,
                headers={
                    "WWW-Authenticate": build_bearer_challenge(
                        settings,
                        error="insufficient_scope",
                        error_description="additional scope is required",
                    )
                },
            )
            return

        await self._app(scope, receive, send)

    async def _authenticate(self, scope: Scope):
        settings: Settings = self._app.state.settings
        auth_header = self._get_header(scope, b"authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise AuthenticationError("Missing bearer token")

        token = auth_header[7:].strip()
        if not token:
            raise AuthenticationError("Missing bearer token")

        introspector: KeycloakTokenIntrospector | None = self._app.state.token_introspector
        if introspector is None:
            raise AuthenticationError("OAuth is not configured")

        return await introspector.authenticate(token)

    @staticmethod
    def _is_public_path(path: str, settings: Settings) -> bool:
        return path == "/health" or path.startswith("/.well-known/") or (
            path == "/oauth/register" and bool(settings.oauth_public_client_id)
        )

    @staticmethod
    def _targets_mcp_path(path: str, settings: Settings) -> bool:
        prefix = settings.mcp_path
        return path == prefix or path.startswith(f"{prefix}/")

    @staticmethod
    def _get_header(scope: Scope, name: bytes) -> str:
        for header_name, header_value in scope.get("headers", []):
            if header_name == name:
                return header_value.decode("utf-8")
        return ""

    @staticmethod
    async def _send_response(
        scope: Scope,
        receive: Receive,
        send: Send,
        *,
        status_code: int,
        headers: dict[str, str],
    ) -> None:
        response = Response(status_code=status_code, headers=headers)
        await response(scope, receive, send)
