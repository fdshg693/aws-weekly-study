# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS Cognito authentication infrastructure built with Terraform. This is a learning/experimentation project that provisions a Cognito User Pool, Client, and optional Domain for Hosted UI. Includes a Vue 3 SPA with manual PKCE implementation, hosted on AWS Amplify. All documentation and comments are in Japanese.

## Common Commands

```bash
# Initialize Terraform
make init

# Format, validate, and plan (dev)
make all

# Plan and apply (dev environment)
# apply はTerraform適用後にフロントエンドのビルド＆Amplifyデプロイも自動実行
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
```

All `make plan/apply/destroy` targets use `-var-file="dev.tfvars"` by default. Prod targets use `prod.tfvars`.

## Architecture

Single-directory Terraform project with Cognito resources defined in `cognito.tf` and Amplify Hosting in `amplify.tf`:

### Cognito (`cognito.tf`)
- **`aws_cognito_user_pool.main`** - User directory with email-based auth, configurable password policy, MFA (TOTP), and environment-based deletion protection
- **`aws_cognito_user_pool_client.main`** - API client supporting USER_PASSWORD_AUTH, USER_SRP_AUTH, and REFRESH_TOKEN_AUTH flows (no client secret)
- **`aws_cognito_user_pool_domain.main`** - Optional Hosted UI domain (conditional via `create_user_pool_domain`)

### Amplify Hosting (`amplify.tf`)
- **`aws_amplify_app.frontend`** - Vue SPA配信用の静的サイトホスティング（Git連携なし、手動デプロイ）
- **`aws_amplify_branch.main`** - デプロイターゲットブランチ
- **`local_file.frontend_config`** - TerraformのOutputからVue SPAの設定ファイル（`frontend/public/config.json`）を生成

### Frontend (`frontend/`)
- Vue 3 + Vite SPA（aws-amplify SDKを使わず手動PKCE実装）
- `src/auth/pkce.js` - code_verifier/code_challenge生成（Web Crypto API）
- `src/auth/cognito.js` - Cognito OAuth endpoints（/oauth2/authorize, /oauth2/token, /logout）
- `src/auth/tokenStore.js` - sessionStorageベースのトークン管理 + JWTデコード
- 実行時に `/config.json` を読み込み（Terraform生成）、なければVite環境変数にフォールバック

Environment differentiation is handled via tfvars files (`dev.tfvars` / `prod.tfvars`). Nearly all settings are parameterized in `variables.tf` with validation rules.

## Key Files

- `cognito.tf` - All Cognito resource definitions
- `amplify.tf` - Amplify Hosting resources and frontend config.json generation
- `variables.tf` - All variable definitions with validation
- `outputs.tf` - Exports pool ID, client ID, endpoints, Amplify URL, and test command templates
- `test_auth_flow.sh` - End-to-end bash test: sign-up, admin-confirm, login, token decode, get-user, token refresh, cleanup. Reads config from `terraform output`.
- `frontend/src/auth/pkce.js` - Manual PKCE implementation (generateCodeVerifier, generateCodeChallenge)
- `frontend/src/auth/cognito.js` - Cognito OAuth helper (authorize URL, token exchange, logout URL)
- `frontend/src/auth/tokenStore.js` - sessionStorage token management and JWT decode

## Important Patterns

- Resource names auto-generate from `project_name` and `environment` variables when specific names are empty
- Prod environment automatically enables `deletion_protection = "ACTIVE"`
- Domain prefix must be globally unique across all AWS accounts
- Device tracking is intentionally disabled (commented out in `cognito.tf`) because it requires SRP libraries incompatible with CLI/bash testing
- The test script uses `admin-confirm-sign-up` to bypass email verification
- Vue SPAはaws-amplify SDKを使わず手動でPKCE（RFC 7636）を実装（教育目的）
- `frontend/public/config.json` はTerraformが生成するためgitignore対象
- Amplify Hostingは手動デプロイ方式（Git連携なし）。`make apply` でTerraform適用後に自動でビルド＆デプロイ実行
- 初回デプロイ時はAmplify URLが未確定のため、2回 `make apply` が必要（1回目でAmplify作成→URLをdev.tfvarsに追加→2回目でcallback URLs更新）
