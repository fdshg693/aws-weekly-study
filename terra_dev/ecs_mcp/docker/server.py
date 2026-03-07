"""FastMCP を HTTP サーバーとして公開するための薄いラッパー。

ポイント:
- `python/main.py` は変更しない
- `/mcp` は FastMCP の streamable-http で公開する
- `/health` は ALB / ECS のヘルスチェック専用に 200 を返す
- `stateless_http=True` により、ALB 配下で複数タスクへ広げやすくする
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

# pyright: reportMissingImports=false
import uvicorn
from starlette.responses import JSONResponse

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


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level=LOG_LEVEL)
