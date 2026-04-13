# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

## Project Overview

Python 製の FastMCP サーバーを Docker 化し、AWS 上で **ECR + ECS Fargate + ALB + ACM + Keycloak(OIDC/OAuth)** を使って公開する学習用 Terraform プロジェクトです。
Keycloak 本体も、このプロジェクト内で **ECS Fargate + RDS PostgreSQL** として AWS 管理できます。

このプロジェクトでは以下を学べます。

- FastMCP サーバーのコンテナ化
- ECR へのイメージ格納
- ECS Fargate での常時稼働
- ALB での HTTPS 終端とパスベースルーティング
- Keycloak を AWS 上で運用する構成
- CloudWatch Logs / Container Insights による監視

## Architecture

### サーバーサイド OAuth（Claude Desktop 等 MCP クライアント向け）
```text
Claude Desktop
  ↓ HTTPS + Bearer token
ALB
  ├─ /keycloak/*      → ECS (Keycloak)
  ├─ /.well-known/*  → ECS (OAuth メタデータ)
  ├─ /mcp            → ECS (Keycloak introspection → FastMCP)
  └─ /health         → ECS (ヘルスチェック)
                    ↓
          docker/mcp_gateway (OAuth middleware + ASGI routing)
                    ↓
             python/main.py (FastMCP)

別経路:
  /keycloak/* → ECS Keycloak → RDS PostgreSQL

OAuth フロー:
  1. Claude Desktop → GET /mcp → 401 Unauthorized
  2. Claude Desktop → GET /.well-known/oauth-authorization-server → Keycloak 情報取得
  3. Claude Desktop → Keycloak 認可エンドポイント（PKCE）→ ユーザーログイン
  4. Keycloak → https://claude.ai/api/mcp/auth_callback → Claude Desktop がトークン取得
  5. Claude Desktop → GET /mcp (Authorization: Bearer <token>) → 正常応答
```

## Key Files

- `provider.tf` - AWS provider と共通タグ設定
- `variables.tf` - ACM / Keycloak / Route53 / ECS / RDS / Docker 関連の変数定義
- `vpc.tf` - VPC / public-private subnet / NAT Gateway / route table
- `security_groups.tf` - ALB / ECS タスク用セキュリティグループ
- `ecr.tf` - ECR リポジトリ
- `iam.tf` - ECS タスク実行ロール
- `keycloak.tf` - Keycloak realm / endpoint / audience 解決用 locals
- `keycloak_aws.tf` - Keycloak 用 ECS / RDS / ALB ルーティング
- `alb.tf` - ALB / HTTPS listener / Route53 レコード
- `ecs.tf` - ECS Cluster / Task Definition / Service / CloudWatch Logs
- `outputs.tf` - ALB URL、Keycloak 情報、ECR URL などの出力
- `docker/Dockerfile` - FastMCP コンテナイメージ作成用
- `docker/server.py` - Uvicorn エントリポイント
- `docker/mcp_gateway/` - 設定、Keycloak 認証、ASGI アプリ
- `python/main.py` - FastMCP サーバー本体
- `dev.tfvars` - 開発用サンプル値
- `prod.tfvars` - 本番用サンプル値
- `README.md` - 前提条件、適用手順、ECR push 手順、注意点

## Important Patterns

- `python/main.py` は MCP ツール定義に集中させ、HTTP / OAuth は `docker/mcp_gateway/` に分離する
- 認証は `enable_server_oauth` によるサーバーサイド OAuth を前提とする
- MCP サーバー自身が Keycloak へ introspection を行う（Claude Desktop 向け）
- `deploy_keycloak_on_aws = true` の場合、Keycloak のインフラは Terraform で AWS に作成する
- Keycloak の realm / client / scope 自体は初回起動後に Admin Console で設定する
- `keycloak.tf` 内の locals が issuer / auth / token / userinfo / introspection endpoint を組み立てる
- 方式 B では `docker/mcp_gateway/` が OAuth ミドルウェア + メタデータエンドポイントを提供する
- HTTPS 証明書は ACM、証明書 ARN は変数で渡す
- Route53 レコード作成は任意で、既存 DNS を使う場合は無効化できる
- `desired_count = 0` で初回 apply し、ECR push 後にタスク数を増やす運用を想定
- `keycloak_path = "/keycloak"` 配下で Keycloak を公開するため、issuer もそのパスを含む
- ECS Cluster では Container Insights を有効化している
- タスクは private subnet に配置し、ALB 経由のみで到達させる

## Common Flow

1. `dev.tfvars` または `prod.tfvars` のプレースホルダーを実値に置き換える
2. `terraform init`
3. `terraform apply -var-file=dev.tfvars`（最初は `desired_count = 0` 推奨）
4. `terraform output keycloak_admin_console_url` を開き、Keycloak の realm / client / scope / audience mapper を作成する
5. ECR に Docker イメージを push
6. `desired_count` を 1 以上にして再度 apply
7. 必要に応じて Keycloak の DCR を有効化し、trusted hosts を設定する
8. Claude Desktop 連携時: `terraform output claude_desktop_client_id` で Client ID を確認し、Claude Desktop の Settings > Connectors から登録

## Notes

- このプロジェクトは学習用なので、コメントを多めに書いて理解しやすさを優先しています
- `allowed_cidrs` は学習中は広く開けられますが、本番では必ず制限してください
- OIDC をまだ準備していない学習段階では `enable_server_oauth = false` で疎通確認できますが、最終的には認証有効化が前提です
- Keycloak 本番運用では HTTPS、固定ホスト名、reverse proxy 配下、管理 UI の公開制限を徹底してください
- Keycloak の初期管理者パスワードと DB パスワードは `tfvars` のプレースホルダーから必ず変更してください
