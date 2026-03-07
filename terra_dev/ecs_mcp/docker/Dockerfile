FROM python:3.12-slim

# Python の基本挙動をコンテナ向けに調整する。
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/python \
    HOST=0.0.0.0 \
    PORT=8000 \
    MCP_PATH=/mcp \
    MCP_STATELESS_HTTP=true

WORKDIR /app

# 依存を先に入れてレイヤーキャッシュを効かせる。
COPY docker/requirements.txt /app/docker/requirements.txt
RUN pip install --no-cache-dir -r /app/docker/requirements.txt

# main.py はそのままコピーし、HTTP 化はラッパー側で行う。
COPY python/main.py /app/python/main.py
COPY docker/server.py /app/docker/server.py

EXPOSE 8000

CMD ["python", "/app/docker/server.py"]
