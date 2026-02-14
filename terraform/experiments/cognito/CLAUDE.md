# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS Cognito authentication infrastructure built with Terraform. This is a learning/experimentation project that provisions a Cognito User Pool, Client, and optional Domain for Hosted UI. All documentation and comments are in Japanese.

## Common Commands

```bash
# Initialize Terraform
make init

# Format, validate, and plan (dev)
make all

# Plan and apply (dev environment)
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
```

All `make plan/apply/destroy` targets use `-var-file="dev.tfvars"` by default. Prod targets use `prod.tfvars`.

## Architecture

Single-directory Terraform project with three Cognito resources defined in `cognito.tf`:
- **`aws_cognito_user_pool.main`** - User directory with email-based auth, configurable password policy, MFA (TOTP), and environment-based deletion protection
- **`aws_cognito_user_pool_client.main`** - API client supporting USER_PASSWORD_AUTH, USER_SRP_AUTH, and REFRESH_TOKEN_AUTH flows (no client secret)
- **`aws_cognito_user_pool_domain.main`** - Optional Hosted UI domain (conditional via `create_user_pool_domain`)

Environment differentiation is handled via tfvars files (`dev.tfvars` / `prod.tfvars`). Nearly all settings are parameterized in `variables.tf` with validation rules.

## Key Files

- `cognito.tf` - All Cognito resource definitions
- `variables.tf` - All variable definitions with validation
- `outputs.tf` - Exports pool ID, client ID, endpoints, and test command templates
- `test_auth_flow.sh` - End-to-end bash test: sign-up, admin-confirm, login, token decode, get-user, token refresh, cleanup. Reads config from `terraform output`.

## Important Patterns

- Resource names auto-generate from `project_name` and `environment` variables when specific names are empty
- Prod environment automatically enables `deletion_protection = "ACTIVE"`
- Domain prefix must be globally unique across all AWS accounts
- Device tracking is intentionally disabled (commented out in `cognito.tf`) because it requires SRP libraries incompatible with CLI/bash testing
- The test script uses `admin-confirm-sign-up` to bypass email verification
