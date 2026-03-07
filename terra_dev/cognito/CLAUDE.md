# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS Cognito authentication infrastructure built with Terraform. This is a learning/experimentation project that provisions a Cognito User Pool, Client, Domain, and a BFF (Backend For Frontend) deployed on Lambda + API Gateway. Includes a Vue 3 SPA hosted on AWS Amplify. Sessions are stored in DynamoDB. All documentation and comments are in Japanese.

## Common Commands

```bash
# Initialize Terraform
make init

# Format, validate, and plan (dev)
make all

# Plan and apply (dev environment)
# apply はBFF Lambdaパッケージング → Terraform適用 → フロントエンドビルド＆Amplifyデプロイを自動実行
make plan
make apply

# Plan and apply (prod environment - interactive confirmation)
make plan-prod
make apply-prod

# Run auth flow integration test (sign-up, login, token refresh, etc.)
make test

# Show Terraform outputs
make output

# Destroy dev resources
make destroy

# Frontend (Vue SPA)
make frontend-install    # npm install
make frontend-dev        # 開発サーバー起動（localhost:5173）
make frontend-build      # ビルド
make frontend-deploy     # ビルド＆Amplifyにデプロイ

# BFF (Backend For Frontend)
make bff-install         # npm install（全依存関係）
make bff-dev             # BFF開発サーバー起動（localhost:3000）
make bff-package         # Lambda用パッケージング（npm ci --omit=dev）
make bff-logs            # Lambda CloudWatch Logsをtail表示
make bff-invoke          # Lambda ヘルスチェック（API Gateway経由）
make dev                 # 開発環境の起動手順を表示

# 開発時の起動手順（ターミナル2つ必要）
# ターミナル1: make bff-dev
# ターミナル2: make frontend-dev
# ブラウザ: http://localhost:5173
```

All `make plan/apply/destroy` targets use `-var-file="dev.tfvars"` by default. Prod targets use `prod.tfvars`.

## Architecture

```
[Amplify (Vue SPA)] --CORS--> [API Gateway HTTP API v2] --> [Lambda (Express + serverless-http)]
                                                                    |
                                                              [DynamoDB (sessions)]
                                                                    |
                                                              [Cognito User Pool]
```

### Cognito (`cognito.tf`)
- **`aws_cognito_user_pool.main`** - User directory with email-based auth, configurable password policy, MFA (TOTP), and environment-based deletion protection
- **`aws_cognito_user_pool_client.main`** - Confidential client with client_secret (BFF用). USER_PASSWORD_AUTH, USER_SRP_AUTH, REFRESH_TOKEN_AUTH flows
- **`aws_cognito_user_pool_domain.main`** - Optional Hosted UI domain (conditional via `create_user_pool_domain`)

### Amplify Hosting (`amplify.tf`)
- **`aws_amplify_app.frontend`** - Vue SPA配信用の静的サイトホスティング（Git連携なし、手動デプロイ）
- **`aws_amplify_branch.main`** - デプロイターゲットブランチ
- **`local_file.frontend_config`** - TerraformのOutputからVue SPAの設定ファイル（`frontend/public/config.json`）を生成。`bffUrl`（API Gateway URL）を含む
- **`local_file.bff_config`** - TerraformのOutputからBFF設定ファイル（`bff/config.json`）を生成（client_secret含む、ローカル開発用）

### Lambda + API Gateway + DynamoDB (`lambda.tf`)
- **`aws_dynamodb_table.bff_sessions`** - セッション・一時データ保存（PAY_PER_REQUEST、TTL有効）
- **`aws_lambda_function.bff`** - Express.js BFFをserverless-httpでラップしたLambda関数（Node.js 20.x）
- **`aws_apigatewayv2_api.bff`** - HTTP API v2（CORS設定付き、$defaultルートで全パスをLambdaに転送）
- **`aws_iam_role.bff_lambda`** - Lambda実行ロール（CloudWatch Logs + DynamoDB CRUD）

### BFF (`bff/`)
- Express.js BFF（Backend For Frontend）サーバー — トークンをサーバーサイドで管理しHttpOnly Cookieでセッション管理
- `server.js` - ローカル開発用エントリーポイント（Express + app.listen）
- `lambda.js` - Lambda用エントリーポイント（serverless-httpでExpressをラップ）
- `config.js` - 設定管理（Terraform生成config.json or 環境変数）
- `auth/routes.js` - 認証API（/auth/login, /auth/callback, /auth/logout, /auth/me, /auth/refresh）
- `auth/cognito.js` - サーバーサイドCognito OAuth（PKCE + client_secret + state + nonce）
- `auth/session.js` - セッション管理 + 認可フロー一時データ管理（ストア抽象化経由）
- `auth/sessionStore.js` - ストアファクトリ（環境変数で切り替え: memory or dynamodb）
- `auth/stores/memoryStore.js` - インメモリストア（ローカル開発用）
- `auth/stores/dynamodbStore.js` - DynamoDBストア（Lambda環境用、TTL対応）
- `auth/jwt.js` - JWKSベースのJWT署名検証（joseライブラリ使用）
- `auth/csrf.js` - CSRF保護（Double Submit Cookieパターン、Lambda環境でSameSite=None対応）

### Frontend (`frontend/`)
- Vue 3 + Vite SPA — BFF APIクライアントとして動作
- `src/auth/cognito.js` - BFF API呼び出し（/auth/me, /auth/logout, /auth/refresh）+ CSRFトークン管理 + BFF URL初期化
- `src/auth/pkce.js` - （参考用）SPA版のPKCE手動実装コード（BFF版では未使用）
- `src/auth/tokenStore.js` - （参考用）SPA版のsessionStorage管理コード（BFF版では未使用）
- Viteプロキシで `/auth/*` をBFF（localhost:3000）に転送（ローカル開発時）
- Amplifyデプロイ時は config.json の `bffUrl` からAPI Gateway URLを取得

Environment differentiation is handled via tfvars files (`dev.tfvars` / `prod.tfvars`). Nearly all settings are parameterized in `variables.tf` with validation rules.

## Key Files

- `cognito.tf` - All Cognito resource definitions
- `amplify.tf` - Amplify Hosting resources and frontend config.json generation (includes bffUrl)
- `lambda.tf` - Lambda, API Gateway HTTP API, DynamoDB, IAM resources
- `variables.tf` - All variable definitions with validation
- `outputs.tf` - Exports pool ID, client ID, endpoints, Amplify URL, BFF API URL, and test command templates
- `test_auth_flow.sh` - End-to-end bash test: sign-up, admin-confirm, login, token decode, get-user, token refresh, cleanup
- `bff/server.js` - BFF entry point for local development (Express server)
- `bff/lambda.js` - BFF entry point for Lambda (serverless-http wrapper)
- `bff/auth/routes.js` - Auth endpoints: login, callback, logout, me, refresh
- `bff/auth/cognito.js` - Server-side Cognito OAuth (PKCE + client_secret + state + nonce)
- `bff/auth/session.js` - Session management with store abstraction + pending authorization management
- `bff/auth/sessionStore.js` - Store factory (memory or DynamoDB based on SESSION_STORE_TYPE env var)
- `bff/auth/stores/memoryStore.js` - In-memory store for local development
- `bff/auth/stores/dynamodbStore.js` - DynamoDB store for Lambda (TTL-based expiration)
- `bff/auth/jwt.js` - JWKS-based JWT verification (jose library)
- `bff/auth/csrf.js` - CSRF protection (Double Submit Cookie, SameSite=None for Lambda)
- `frontend/src/auth/cognito.js` - BFF API client with bffUrl initialization

## Important Patterns

- Resource names auto-generate from `project_name` and `environment` variables when specific names are empty
- Prod environment automatically enables `deletion_protection = "ACTIVE"`
- Domain prefix must be globally unique across all AWS accounts
- Device tracking is intentionally disabled (commented out in `cognito.tf`) because it requires SRP libraries incompatible with CLI/bash testing
- The test script uses `admin-confirm-sign-up` to bypass email verification
- BFFパターン: トークンはサーバーサイドのみに保持、ブラウザにはHttpOnly CookieのセッションIDのみ
- BFFはConfidential Client（client_secret + PKCE）として動作し、state/nonceも実装
- JWT署名検証はBFFサーバーでJWKSを使って実施（joseライブラリ）
- CSRF保護はDouble Submit Cookieパターン（csrf_token Cookie + x-csrf-token ヘッダー）
- セッションストアは環境変数 `SESSION_STORE_TYPE` で切り替え: `memory`（ローカル）/ `dynamodb`（Lambda）
- Lambda環境のCookieは `SameSite=None; Secure` （クロスオリジン対応）
- `bff/config.json` はTerraformが生成（client_secret含む、ローカル開発用）ためgitignore対象
- `frontend/public/config.json` はTerraformが生成するためgitignore対象
- Vite開発サーバーのプロキシで `/auth/*` をBFF（localhost:3000）に転送
- Amplifyデプロイ時はフロントエンドが `config.json` の `bffUrl` からAPI Gateway URLを動的に取得
- Amplify Hostingは手動デプロイ方式（Git連携なし）。`make apply` でBFFパッケージング → Terraform適用 → フロントエンドビルド＆デプロイを自動実行
- 初回デプロイ時はAmplify URL・API Gateway URLが未確定のため、2回 `make apply` が必要（1回目で作成→URLをdev.tfvarsのcallback_urlsに追加→2回目でCognito callback URLs更新）
