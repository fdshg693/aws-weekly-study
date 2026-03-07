# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

## Project Overview

Python 製の FastMCP サーバーを、コード本体 `python/main.py` を変更せずに Docker 化し、AWS 上で **ECR + ECS Fargate + ALB + ACM + OIDC 認証** を使って公開する学習用 Terraform プロジェクトです。

このプロジェクトでは以下を学べます。

- FastMCP サーバーのコンテナ化
- ECR へのイメージ格納
- ECS Fargate での常時稼働
- ALB での HTTPS 終端とパスベースルーティング
- ALB の `authenticate-oidc` によるアプリ無改造の認証
- CloudWatch Logs / Container Insights による監視

## Architecture

### 方式 A: ALB OIDC 認証（ブラウザ向け）
```text
Browser
  ↓ HTTPS
ALB
  ├─ /mcp    → ALB authenticate-oidc (Cognito) → ECS Fargate task
  └─ /health → そのまま ECS Fargate task
                    ↓
          docker/server.py (ASGI wrapper)
                    ↓
             python/main.py (FastMCP)
```

### 方式 B: サーバーサイド OAuth（Claude Desktop 等 MCP クライアント向け）
```text
Claude Desktop
  ↓ HTTPS + Bearer token
ALB
  ├─ /.well-known/*  → ECS (OAuth メタデータ)
  ├─ /mcp            → ECS (Bearer 検証 → FastMCP)
  └─ /health         → ECS (ヘルスチェック)
                    ↓
          docker/server.py (OAuth middleware + ASGI wrapper)
                    ↓
             python/main.py (FastMCP)

OAuth フロー:
  1. Claude Desktop → GET /mcp → 401 Unauthorized
  2. Claude Desktop → GET /.well-known/oauth-authorization-server → Cognito 情報取得
  3. Claude Desktop → Cognito 認可エンドポイント（PKCE）→ ユーザーログイン
  4. Cognito → https://claude.ai/api/mcp/auth_callback → Claude Desktop がトークン取得
  5. Claude Desktop → GET /mcp (Authorization: Bearer <token>) → 正常応答
```

## Key Files

- `provider.tf` - AWS provider と共通タグ設定
- `variables.tf` - ACM / OIDC / Cognito / Route53 / ECS / Docker 関連の変数定義
- `vpc.tf` - VPC / public-private subnet / NAT Gateway / route table
- `security_groups.tf` - ALB / ECS タスク用セキュリティグループ
- `ecr.tf` - ECR リポジトリ
- `iam.tf` - ECS タスク実行ロール
- `cognito.tf` - Cognito User Pool / Domain / Client（use_cognito = true 時のみ作成）、OIDC エンドポイント解決用 locals
- `alb.tf` - ALB / HTTPS listener / OIDC 認証 / Route53 レコード
- `ecs.tf` - ECS Cluster / Task Definition / Service / CloudWatch Logs
- `outputs.tf` - ALB URL、OIDC callback URL、Cognito 情報、ECR URL などの出力
- `docker/Dockerfile` - FastMCP コンテナイメージ作成用
- `docker/server.py` - `main.py` を変えずに `/mcp` と `/health` を公開する薄いラッパー
- `python/main.py` - 元の FastMCP サーバー本体（変更しない前提）
- `dev.tfvars` - 開発用サンプル値
- `prod.tfvars` - 本番用サンプル値
- `README.md` - 前提条件、適用手順、ECR push 手順、注意点

## Important Patterns

- `python/main.py` は変更せず、`docker/server.py` で ASGI 公開と `/health` を補う
- 認証は2つの方式から選択（排他）:
  - **方式 A (`enable_oidc_auth`)**: ALB の authenticate-oidc でブラウザ向けリダイレクト認証
  - **方式 B (`enable_server_oauth`)**: MCP サーバー自身が Bearer トークンを検証（Claude Desktop 向け）
- OIDC プロバイダーは `use_cognito` フラグで Cognito / 外部 IdP を切り替え可能
  - `use_cognito = true`: Cognito User Pool を Terraform で作成し、OIDC エンドポイントを自動導出
  - `use_cognito = false`: `oidc_*` 変数で外部 IdP（Google, Auth0 等）を手動指定
- `cognito.tf` 内の `local.resolved_oidc_*` が Cognito / 外部 IdP を透過的に解決し、`alb.tf` / `ecs.tf` はその locals を参照する
- 方式 B では `server.py` が OAuth ミドルウェア + メタデータエンドポイントを追加する（`OAUTH_ISSUER` 環境変数の有無で自動切替）
- HTTPS 証明書は ACM、証明書 ARN は変数で渡す
- Route53 レコード作成は任意で、既存 DNS を使う場合は無効化できる
- `desired_count = 0` で初回 apply し、ECR push 後にタスク数を増やす運用を想定
- ECS Cluster では Container Insights を有効化している
- タスクは private subnet に配置し、ALB 経由のみで到達させる

## Common Flow

1. `dev.tfvars` または `prod.tfvars` のプレースホルダーを実値に置き換える
2. `terraform init`
3. `terraform apply -var-file=dev.tfvars`（最初は `desired_count = 0` 推奨）
4. ECR に Docker イメージを push
5. `desired_count` を 1 以上にして再度 apply
6. Cognito 利用時: `aws cognito-idp admin-create-user` でユーザーを作成して動作確認
7. 外部 IdP 利用時: OIDC プロバイダに callback URL を登録して動作確認
8. Claude Desktop 連携時: `terraform output claude_desktop_client_id` で Client ID を確認し、Claude Desktop の Settings > Connectors から登録

## Notes

- このプロジェクトは学習用なので、コメントを多めに書いて理解しやすさを優先しています
- `allowed_cidrs` は学習中は広く開けられますが、本番では必ず制限してください
- OIDC をまだ準備していない学習段階では `enable_oidc_auth = false` で疎通確認できますが、最終的には認証有効化が前提です
- `cognito_domain_prefix` は AWS 全体でグローバルに一意でなければならない
