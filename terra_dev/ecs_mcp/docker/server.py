"""Keycloak 連携対応の FastMCP HTTP エントリポイント。"""

from __future__ import annotations

import sys
from pathlib import Path

import uvicorn

# `python/main.py` を import できるように、コンテナ外のエディタ実行でもパスを補う。
PYTHON_DIR = Path(__file__).resolve().parents[1] / "python"
if str(PYTHON_DIR) not in sys.path:
    sys.path.insert(0, str(PYTHON_DIR))

DOCKER_DIR = Path(__file__).resolve().parent
if str(DOCKER_DIR) not in sys.path:
    sys.path.insert(0, str(DOCKER_DIR))

from main import mcp  # noqa: E402
from mcp_gateway.app import create_application  # noqa: E402
from mcp_gateway.config import Settings  # noqa: E402

settings = Settings()

mcp_app = mcp.http_app(
    path="/",
    transport="streamable-http",
    stateless_http=settings.mcp_stateless_http,
)
app = create_application(mcp_app=mcp_app, settings=settings)


if __name__ == "__main__":
    uvicorn.run(app, host=settings.host, port=settings.port, log_level=settings.log_level)
