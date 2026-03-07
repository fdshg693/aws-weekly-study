"""FastMCP を HTTP サーバーとして公開するための薄いラッパー。

ポイント:
- `python/main.py` は変更しない
- `/mcp` は FastMCP の streamable-http で公開する
- `/health` は ALB / ECS のヘルスチェック専用に 200 を返す
- `stateless_http=True` により、ALB 配下で複数タスクへ広げやすくする
- 環境変数 `OAUTH_ISSUER` が設定されていると、MCP 仕様準拠の
  OAuth 認証（Bearer トークン検証）を有効化する。
  Claude Desktop 等の MCP クライアントからの接続に必要。
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from urllib.request import urlopen

# pyright: reportMissingImports=false
import uvicorn
from starlette.responses import JSONResponse, Response

# `python/main.py` を import できるように、コンテナ外のエディタ実行でもパスを補う。
PYTHON_DIR = Path(__file__).resolve().parents[1] / "python"
if str(PYTHON_DIR) not in sys.path:
    sys.path.insert(0, str(PYTHON_DIR))

from main import mcp  # noqa: E402

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
MCP_PATH = os.getenv("MCP_PATH", "/mcp")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info")
MCP_STATELESS_HTTP = os.getenv("MCP_STATELESS_HTTP", "true").lower() in {
    "1",
    "true",
    "yes",
    "on",
}

# ── OAuth 設定 ──────────────────────────────────────────────────
# 環境変数 OAUTH_ISSUER が設定されている場合に OAuth 認証を有効化する。
# Cognito / 外部 IdP どちらでも、OIDC 準拠の issuer であれば動作する。
#
# 必要な環境変数:
#   OAUTH_ISSUER                 - OIDC issuer URL
#   OAUTH_AUTHORIZATION_ENDPOINT - 認可エンドポイント
#   OAUTH_TOKEN_ENDPOINT         - トークンエンドポイント
#   OAUTH_CLIENT_ID              - MCP クライアント用の OAuth client_id（DCR で返す）
#   PUBLIC_HOSTNAME              - このサーバーの公開ホスト名
# ────────────────────────────────────────────────────────────────
OAUTH_ISSUER = os.getenv("OAUTH_ISSUER", "")
OAUTH_AUTHORIZATION_ENDPOINT = os.getenv("OAUTH_AUTHORIZATION_ENDPOINT", "")
OAUTH_TOKEN_ENDPOINT = os.getenv("OAUTH_TOKEN_ENDPOINT", "")
OAUTH_CLIENT_ID = os.getenv("OAUTH_CLIENT_ID", "")
PUBLIC_HOSTNAME = os.getenv("PUBLIC_HOSTNAME", "localhost")

# JWKS URI は issuer から導出する（OIDC Discovery の規約）。
OAUTH_JWKS_URI = f"{OAUTH_ISSUER}/.well-known/jwks.json" if OAUTH_ISSUER else ""

# FastMCP が用意する ASGI アプリをそのまま利用する。
# これにより main.py のロジックへ手を入れずに HTTP サーバー化できる。
app = mcp.http_app(
    path=MCP_PATH,
    transport="streamable-http",
    stateless_http=MCP_STATELESS_HTTP,
)


@app.route("/health", methods=["GET"])
async def health(_request):
    """ALB / ECS 用のシンプルなヘルスチェックエンドポイント。"""

    return JSONResponse(
        {
            "status": "ok",
            "service": "fastmcp",
            "mcp_path": MCP_PATH,
            "stateless_http": MCP_STATELESS_HTTP,
        }
    )


# ── OAuth 認証（OAUTH_ISSUER 設定時のみ有効）──────────────────────
if OAUTH_ISSUER:
    import jwt  # PyJWT

    # ── JWKS キャッシュ ──
    # OIDC プロバイダーの JWKS エンドポイントへのアクセスを減らすため、
    # 取得した公開鍵セットを 1 時間キャッシュする。
    _jwks_cache: dict = {"keys": None, "fetched_at": 0.0}
    _JWKS_CACHE_TTL = 3600  # seconds

    def _fetch_jwks() -> dict:
        """OIDC プロバイダーから JWKS を取得し、キャッシュする。"""
        now = time.time()
        if _jwks_cache["keys"] and now - _jwks_cache["fetched_at"] < _JWKS_CACHE_TTL:
            return _jwks_cache["keys"]

        with urlopen(OAUTH_JWKS_URI) as resp:
            data = json.loads(resp.read())

        _jwks_cache["keys"] = data
        _jwks_cache["fetched_at"] = now
        return data

    def _validate_bearer_token(token: str) -> dict | None:
        """Bearer トークン（JWT）を検証し、正当ならクレームを返す。

        検証内容:
        - 署名: JWKS の公開鍵で RS256 署名を検証
        - issuer: OAUTH_ISSUER と一致するか
        - 有効期限: exp クレームが現在時刻より未来か
        - aud: Cognito の access_token には aud が無いためスキップ
        """
        try:
            jwks = _fetch_jwks()
            header = jwt.get_unverified_header(token)
            kid = header.get("kid")

            # kid（Key ID）が一致する公開鍵を探す
            rsa_key = None
            for key in jwks.get("keys", []):
                if key.get("kid") == kid:
                    rsa_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
                    break

            if rsa_key is None:
                return None

            return jwt.decode(
                token,
                rsa_key,
                algorithms=["RS256"],
                issuer=OAUTH_ISSUER,
                options={"verify_aud": False},
            )
        except Exception:
            return None

    def _get_header(scope: dict, name: str) -> str:
        """ASGI scope からヘッダー値を取得するヘルパー。"""
        target = name.lower().encode()
        for h_name, h_value in scope.get("headers", []):
            if h_name == target:
                return h_value.decode()
        return ""

    # ── OAuth メタデータエンドポイント ──

    @app.route("/.well-known/oauth-authorization-server", methods=["GET"])
    async def oauth_as_metadata(_request):
        """RFC 8414 Authorization Server Metadata。

        MCP 仕様（2025-03-26）で要求されるエンドポイント。
        Claude Desktop はここから認可・トークンエンドポイントを取得し、
        OAuth Authorization Code + PKCE フローを実行する。

        注意: issuer は実際の認可サーバー（Cognito 等）の値だが、
        MCP 仕様ではこのメタデータを MCP サーバーの URL で提供する。
        """
        base_url = f"https://{PUBLIC_HOSTNAME}"
        return JSONResponse(
            {
                "issuer": OAUTH_ISSUER,
                "authorization_endpoint": OAUTH_AUTHORIZATION_ENDPOINT,
                "token_endpoint": OAUTH_TOKEN_ENDPOINT,
                "registration_endpoint": f"{base_url}/oauth/register",
                "response_types_supported": ["code"],
                "grant_types_supported": ["authorization_code", "refresh_token"],
                "token_endpoint_auth_methods_supported": ["none"],
                "code_challenge_methods_supported": ["S256"],
                "scopes_supported": ["openid", "profile", "email"],
            }
        )

    @app.route("/.well-known/oauth-protected-resource", methods=["GET"])
    async def oauth_pr_metadata(_request):
        """RFC 9728 Protected Resource Metadata。

        MCP 仕様（2025-06-18）で追加されたエンドポイント。
        リソースサーバー（この MCP サーバー）がどの認可サーバーを使うかを示す。
        authorization_servers は自サーバーの URL を返す（AS メタデータを自サーバーで配信するため）。
        """
        base_url = f"https://{PUBLIC_HOSTNAME}"
        return JSONResponse(
            {
                "resource": f"{base_url}{MCP_PATH}",
                "authorization_servers": [base_url],
                "scopes_supported": ["openid", "profile", "email"],
                "bearer_methods_supported": ["header"],
            }
        )

    # ── Dynamic Client Registration (DCR) エンドポイント ──
    # RFC 7591 準拠の簡易実装。
    # Claude Desktop は OAuth メタデータの registration_endpoint に POST して
    # client_id を自動取得する。ここでは事前作成済みの Cognito クライアントの
    # client_id を返すだけの簡易実装。

    @app.route("/oauth/register", methods=["POST"])
    async def oauth_register(_request):
        """RFC 7591 Dynamic Client Registration（簡易実装）。

        Claude Desktop が OAuth フロー開始時に呼び出す。
        事前に Cognito で作成したパブリッククライアントの client_id を返す。
        実際のクライアント作成は行わず、常に同じ client_id を返す。
        """
        return JSONResponse(
            {
                "client_id": OAUTH_CLIENT_ID,
                "client_name": "Claude Desktop",
                "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
                "grant_types": ["authorization_code", "refresh_token"],
                "response_types": ["code"],
                "token_endpoint_auth_method": "none",
            }
        )

    # ── ASGI OAuth ミドルウェア ──
    # BaseHTTPMiddleware ではなく生の ASGI ミドルウェアを使うことで、
    # MCP streamable-http の SSE ストリーミングレスポンスとの互換性を保つ。

    _inner_app = app

    async def _oauth_middleware(scope, receive, send):
        """OAuth Bearer トークンを検証する ASGI ミドルウェア。

        - /health, /.well-known/* → 認証不要（そのまま通す）
        - /mcp* → Bearer トークン必須（無い or 無効なら 401）
        """
        if scope["type"] != "http":
            await _inner_app(scope, receive, send)
            return

        path = scope.get("path", "")

        # 認証不要のパス
        if path == "/health" or path.startswith("/.well-known/") or path.startswith("/oauth/"):
            await _inner_app(scope, receive, send)
            return

        # /mcp* は Bearer トークン必須
        if path.startswith(MCP_PATH):
            auth = _get_header(scope, "authorization")

            if not auth.startswith("Bearer "):
                resp = Response(
                    status_code=401,
                    headers={"WWW-Authenticate": "Bearer"},
                )
                await resp(scope, receive, send)
                return

            token = auth[7:]  # "Bearer " を除去
            claims = _validate_bearer_token(token)
            if claims is None:
                resp = Response(
                    status_code=401,
                    headers={"WWW-Authenticate": 'Bearer error="invalid_token"'},
                )
                await resp(scope, receive, send)
                return

        await _inner_app(scope, receive, send)

    # ミドルウェアでラップした ASGI アプリを app として差し替える
    app = _oauth_middleware


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level=LOG_LEVEL)
