# Amazon Cognito Authentication Flow - CURL Testing Guide

**Generated:** February 7, 2026  
**Purpose:** Comprehensive guide for testing Cognito User Pool authentication using CURL commands

---

## Table of Contents

1. [Overview](#overview)
2. [Required Cognito Resources](#required-cognito-resources)
3. [Terraform Outputs Needed](#terraform-outputs-needed)
4. [Authentication Flow Architecture](#authentication-flow-architecture)
5. [Prerequisites](#prerequisites)
6. [Step-by-Step CURL Commands](#step-by-step-curl-commands)
7. [Important Configuration Notes](#important-configuration-notes)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This guide demonstrates a complete API-based authentication flow for Amazon Cognito User Pools using CURL commands. This flow is ideal for:

- Testing Cognito infrastructure created via Terraform
- Understanding the API interactions in authentication
- Debugging authentication issues
- Learning Cognito authentication patterns

**Authentication Flow Covered:**
1. User Sign-Up
2. User Confirmation (email/SMS verification)
3. User Sign-In (authentication)
4. Token Refresh

---

## Required Cognito Resources

### 1. User Pool

The core directory that stores user information.

**Key Configuration Requirements:**
- Password policy configured
- Email/SMS verification enabled
- Auto-verification settings configured
- User attributes defined (email, phone_number, etc.)

### 2. User Pool Client (App Client)

The application interface to the User Pool.

**Required Settings:**
- **Client ID:** Used in all API calls
- **Client Secret:** (Optional but recommended for confidential clients)
- **Explicit Auth Flows:** Must include the following:
  - `ALLOW_USER_PASSWORD_AUTH` - For direct password authentication
  - `ALLOW_REFRESH_TOKEN_AUTH` - For token refresh operations
  - `ALLOW_USER_SRP_AUTH` - (Optional) For SRP-based authentication
  
**Important:** If your app client has a Client Secret, you MUST compute and include a `SECRET_HASH` parameter in all API requests.

### 3. Optional: User Pool Domain

Only required if using Hosted UI or OAuth flows (not covered in this guide).

---

## Terraform Outputs Needed

Your Terraform configuration should output the following values:

```hcl
# Required outputs for CURL testing
output "user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "The ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "The Client ID for the User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_client_secret" {
  description = "The Client Secret (if configured)"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "user_pool_endpoint" {
  description = "The endpoint URL for Cognito API calls"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/"
}

output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = var.aws_region
}
```

---

## Authentication Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Cognito Authentication Flow                    │
└─────────────────────────────────────────────────────────────────┘

1. SIGN-UP
   ┌──────────┐    SignUp API     ┌──────────────┐
   │  Client  │ ─────────────────> │  Cognito     │
   │  (CURL)  │                    │  User Pool   │
   └──────────┘                    └──────────────┘
                                           │
                                           │ Send verification code
                                           ▼
                                    ┌──────────────┐
                                    │ User's Email │
                                    │  or Phone    │
                                    └──────────────┘

2. CONFIRMATION
   ┌──────────┐  ConfirmSignUp    ┌──────────────┐
   │  Client  │ ─────────────────> │  Cognito     │
   │  (CURL)  │  (with code)       │  User Pool   │
   └──────────┘                    └──────────────┘
                                           │
                                           │ User confirmed
                                           ▼
                                    Status: CONFIRMED

3. SIGN-IN
   ┌──────────┐   InitiateAuth    ┌──────────────┐
   │  Client  │ ─────────────────> │  Cognito     │
   │  (CURL)  │  (credentials)     │  User Pool   │
   └──────────┘                    └──────────────┘
                                           │
                                           │ Return tokens
                                           ▼
                                    ┌──────────────┐
                                    │ ID Token     │
                                    │ Access Token │
                                    │ Refresh Token│
                                    └──────────────┘

4. TOKEN REFRESH
   ┌──────────┐   InitiateAuth    ┌──────────────┐
   │  Client  │ ─────────────────> │  Cognito     │
   │  (CURL)  │ (refresh token)    │  User Pool   │
   └──────────┘                    └──────────────┘
                                           │
                                           │ Return new tokens
                                           ▼
                                    ┌──────────────┐
                                    │ New ID Token │
                                    │ New Access   │
                                    └──────────────┘
```

---

## Prerequisites

### Environment Variables

Set these before running the CURL commands:

```bash
# Required for all commands
export AWS_REGION="us-east-1"
export CLIENT_ID="your_client_id_here"
export COGNITO_ENDPOINT="https://cognito-idp.${AWS_REGION}.amazonaws.com/"

# Required ONLY if your app client has a Client Secret
export CLIENT_SECRET="your_client_secret_here"

# Test user credentials
export TEST_USERNAME="testuser@example.com"
export TEST_PASSWORD="YourSecurePassword123!"
export TEST_EMAIL="testuser@example.com"
```

### Computing SECRET_HASH

If your User Pool Client has a Client Secret configured, you MUST include a `SECRET_HASH` parameter in your API requests.

**Formula:**
```
SECRET_HASH = Base64(HMAC_SHA256(Client_Secret, Username + Client_ID))
```

**Shell Script to Compute SECRET_HASH:**

```bash
#!/bin/bash
# compute_secret_hash.sh

USERNAME="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"

# Compute the secret hash
SECRET_HASH=$(echo -n "${USERNAME}${CLIENT_ID}" | \
  openssl dgst -sha256 -hmac "${CLIENT_SECRET}" -binary | \
  openssl enc -base64)

echo "$SECRET_HASH"
```

**Usage:**
```bash
chmod +x compute_secret_hash.sh
export SECRET_HASH=$(./compute_secret_hash.sh "$TEST_USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")
echo "SECRET_HASH: $SECRET_HASH"
```

**Python Alternative:**
```python
import hmac
import hashlib
import base64
import sys

def calculate_secret_hash(username, client_id, client_secret):
    message = bytes(username + client_id, 'utf-8')
    secret = bytes(client_secret, 'utf-8')
    dig = hmac.new(secret, message, hashlib.sha256).digest()
    return base64.b64encode(dig).decode()

if __name__ == "__main__":
    username = sys.argv[1]
    client_id = sys.argv[2]
    client_secret = sys.argv[3]
    print(calculate_secret_hash(username, client_id, client_secret))
```

---

## Step-by-Step CURL Commands

### Step 1: User Sign-Up

Register a new user in the User Pool.

**Without Client Secret:**

```bash
curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "Username": "'"${TEST_USERNAME}"'",
    "Password": "'"${TEST_PASSWORD}"'",
    "UserAttributes": [
      {
        "Name": "email",
        "Value": "'"${TEST_EMAIL}"'"
      }
    ]
  }'
```

**With Client Secret:**

```bash
# First compute SECRET_HASH
export SECRET_HASH=$(./compute_secret_hash.sh "$TEST_USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")

curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "SecretHash": "'"${SECRET_HASH}"'",
    "Username": "'"${TEST_USERNAME}"'",
    "Password": "'"${TEST_PASSWORD}"'",
    "UserAttributes": [
      {
        "Name": "email",
        "Value": "'"${TEST_EMAIL}"'"
      }
    ]
  }'
```

**Expected Success Response:**

```json
{
  "UserConfirmed": false,
  "UserSub": "a1b2c3d4-5678-90ab-cdef-EXAMPLE11111",
  "CodeDeliveryDetails": {
    "Destination": "t***@e***.com",
    "DeliveryMedium": "EMAIL",
    "AttributeName": "email"
  }
}
```

**Important Notes:**
- User is created in `UNCONFIRMED` status
- Confirmation code is sent to the email/phone
- Code is valid for 24 hours
- `UserSub` is the unique identifier for the user

---

### Step 2: Confirm User Sign-Up

Confirm the user account using the verification code sent via email/SMS.

**Without Client Secret:**

```bash
# Replace VERIFICATION_CODE with the code received
export VERIFICATION_CODE="123456"

curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.ConfirmSignUp" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "Username": "'"${TEST_USERNAME}"'",
    "ConfirmationCode": "'"${VERIFICATION_CODE}"'"
  }'
```

**With Client Secret:**

```bash
# Compute SECRET_HASH (if not already set)
export SECRET_HASH=$(./compute_secret_hash.sh "$TEST_USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")

curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.ConfirmSignUp" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "SecretHash": "'"${SECRET_HASH}"'",
    "Username": "'"${TEST_USERNAME}"'",
    "ConfirmationCode": "'"${VERIFICATION_CODE}"'"
  }'
```

**Expected Success Response:**

```json
{}
```

**Important Notes:**
- Empty response indicates success
- User status changes to `CONFIRMED`
- Email/phone attribute is marked as `verified`
- User can now sign in

---

### Step 3: User Sign-In (Authentication)

Authenticate the user and receive JWT tokens.

**Authentication Flow: USER_PASSWORD_AUTH**

This flow sends username and password directly (not recommended for production client-side apps, but useful for testing and server-side applications).

**Without Client Secret:**

```bash
curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "USER_PASSWORD_AUTH",
    "AuthParameters": {
      "USERNAME": "'"${TEST_USERNAME}"'",
      "PASSWORD": "'"${TEST_PASSWORD}"'"
    }
  }'
```

**With Client Secret:**

```bash
# Compute SECRET_HASH
export SECRET_HASH=$(./compute_secret_hash.sh "$TEST_USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")

curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "USER_PASSWORD_AUTH",
    "AuthParameters": {
      "USERNAME": "'"${TEST_USERNAME}"'",
      "PASSWORD": "'"${TEST_PASSWORD}"'",
      "SECRET_HASH": "'"${SECRET_HASH}"'"
    }
  }'
```

**Expected Success Response:**

```json
{
  "AuthenticationResult": {
    "AccessToken": "eyJraWQiOiJLTzRVMWZs...(very long token)...xCQ",
    "ExpiresIn": 3600,
    "TokenType": "Bearer",
    "RefreshToken": "eyJjdHkiOiJKV1QiLCJ...(very long token)...fQ",
    "IdToken": "eyJraWQiOiJhU2VGRFh...(very long token)...gj"
  },
  "ChallengeParameters": {}
}
```

**Token Details:**

| Token | Purpose | Expiration | Usage |
|-------|---------|------------|-------|
| **IdToken** | Contains user identity claims (name, email, etc.) | 1 hour (default) | Pass to your backend to validate user identity |
| **AccessToken** | Authorizes API operations on user data | 1 hour (default) | Use for Cognito API calls requiring authentication |
| **RefreshToken** | Obtains new ID and Access tokens | 30 days (default, configurable up to 10 years) | Use to get new tokens without re-authentication |

**Save the tokens for later use:**

```bash
# Parse and save tokens using jq
export ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.AccessToken')
export ID_TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.IdToken')
export REFRESH_TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.RefreshToken')
```

---

### Step 4: Token Refresh

Obtain new tokens using the refresh token without requiring the user to sign in again.

**Authentication Flow: REFRESH_TOKEN_AUTH**

**Without Client Secret:**

```bash
curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "REFRESH_TOKEN_AUTH",
    "AuthParameters": {
      "REFRESH_TOKEN": "'"${REFRESH_TOKEN}"'"
    }
  }'
```

**With Client Secret:**

```bash
# For REFRESH_TOKEN_AUTH with secret, use the 'sub' claim from the ID token as username
# Extract 'sub' from ID token (requires decoding JWT - base64 decode the payload part)
export USER_SUB=$(echo $ID_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.sub')

# Compute SECRET_HASH using sub instead of username
export SECRET_HASH=$(./compute_secret_hash.sh "$USER_SUB" "$CLIENT_ID" "$CLIENT_SECRET")

curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "REFRESH_TOKEN_AUTH",
    "AuthParameters": {
      "REFRESH_TOKEN": "'"${REFRESH_TOKEN}"'",
      "SECRET_HASH": "'"${SECRET_HASH}"'"
    }
  }'
```

**Expected Success Response:**

```json
{
  "AuthenticationResult": {
    "AccessToken": "eyJraWQiOiJLTzRVMWZs...(new token)...xCQ",
    "ExpiresIn": 3600,
    "TokenType": "Bearer",
    "IdToken": "eyJraWQiOiJhU2VGRFh...(new token)...gj"
  },
  "ChallengeParameters": {}
}
```

**Important Notes:**
- The refresh token is **NOT** returned again (unless refresh token rotation is enabled)
- Only new `AccessToken` and `IdToken` are issued
- Original refresh token remains valid until expiration
- If refresh token rotation is enabled, you'll receive a new refresh token

---

### Alternative: GetTokensFromRefreshToken API

If you have **Refresh Token Rotation** enabled in your app client, you must use this API instead:

```bash
curl -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.GetTokensFromRefreshToken" \
  -d '{
    "ClientId": "'"${CLIENT_ID}"'",
    "RefreshToken": "'"${REFRESH_TOKEN}"'"
  }'
```

**With Refresh Token Rotation:**
- Returns new Access Token, ID Token, **AND** a new Refresh Token
- Original refresh token is revoked after the grace period expires
- More secure for long-lived applications

---

## Important Configuration Notes

### 1. User Pool Client Auth Flows

Your Terraform User Pool Client must explicitly enable these auth flows:

```hcl
resource "aws_cognito_user_pool_client" "main" {
  name         = "my-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",      # Required for direct password authentication
    "ALLOW_REFRESH_TOKEN_AUTH",      # Required for token refresh
    "ALLOW_USER_SRP_AUTH"            # Optional: for SRP authentication
  ]

  # If generating a client secret
  generate_secret = true  # Set to false if you don't want a secret

  # Token expiration settings
  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 60

  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }
}
```

### 2. Password Policy

Ensure your User Pool has a password policy that your test password meets:

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "my-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}
```

### 3. Auto-Verification Settings

Configure which attributes are auto-verified:

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "my-user-pool"

  auto_verified_attributes = ["email"]  # or ["phone_number"] or both

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}
```

### 4. Required Attributes

Define which user attributes are required at sign-up:

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "my-user-pool"

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
}
```

---

## Troubleshooting

### Common Errors and Solutions

#### 1. "Unable to verify secret hash for client"

**Cause:** 
- Incorrect `SECRET_HASH` calculation
- Wrong username used in hash calculation
- Client secret mismatch

**Solution:**
- Verify you're using the correct username (same as in the API call)
- For refresh token requests, use the `sub` claim instead of username
- Double-check your client secret value
- Use the shell script or Python script provided above

#### 2. "InvalidParameterException: Missing required parameter CLIENT_ID"

**Cause:** Missing or incorrect `ClientId` parameter

**Solution:**
- Verify `CLIENT_ID` environment variable is set
- Check that the Client ID is correct

#### 3. "User does not exist"

**Cause:** User hasn't been created yet or is in a different user pool

**Solution:**
- Complete Step 1 (Sign-Up) first
- Verify you're using the correct User Pool and Client

#### 4. "User is not confirmed"

**Cause:** Attempting to sign in before confirming the account

**Solution:**
- Complete Step 2 (Confirm Sign-Up) first
- Or use `AdminConfirmSignUp` API as an administrator

#### 5. "NotAuthorizedException: Incorrect username or password"

**Cause:** Wrong credentials or user doesn't exist

**Solution:**
- Verify username and password are correct
- Ensure user has been confirmed
- Check password meets policy requirements

#### 6. "InvalidParameterException: Cannot enable features requiring managed login for app clients without a user pool domain"

**Cause:** Trying to use features that require a Hosted UI without a domain

**Solution:**
- For API-based authentication (CURL testing), you don't need a domain
- Remove any features that require managed login

#### 7. "Token has expired"

**Cause:** Access or ID token has expired (default 1 hour)

**Solution:**
- Use the refresh token to get new tokens (Step 4)
- Access and ID tokens are short-lived by design

#### 8. "Refresh Token has expired"

**Cause:** Refresh token expired (default 30 days)

**Solution:**
- User must sign in again with username and password
- Consider increasing refresh token validity in production

---

## Complete Testing Script

Here's a complete bash script that performs all steps:

```bash
#!/bin/bash
# cognito_test_flow.sh

set -e  # Exit on error

# Configuration
AWS_REGION="us-east-1"
CLIENT_ID="your_client_id"
CLIENT_SECRET="your_client_secret"  # Leave empty if no secret
COGNITO_ENDPOINT="https://cognito-idp.${AWS_REGION}.amazonaws.com/"

# Test user
USERNAME="testuser@example.com"
PASSWORD="TestPassword123!"
EMAIL="testuser@example.com"

# Helper function to compute secret hash
compute_secret_hash() {
  local username=$1
  local client_id=$2
  local client_secret=$3
  
  echo -n "${username}${client_id}" | \
    openssl dgst -sha256 -hmac "${client_secret}" -binary | \
    openssl enc -base64
}

echo "=== Step 1: Sign Up ==="
if [ -n "$CLIENT_SECRET" ]; then
  SECRET_HASH=$(compute_secret_hash "$USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")
  SIGNUP_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "SecretHash": "'"${SECRET_HASH}"'",
    "Username": "'"${USERNAME}"'",
    "Password": "'"${PASSWORD}"'",
    "UserAttributes": [{"Name": "email", "Value": "'"${EMAIL}"'"}]
  }'
else
  SIGNUP_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "Username": "'"${USERNAME}"'",
    "Password": "'"${PASSWORD}"'",
    "UserAttributes": [{"Name": "email", "Value": "'"${EMAIL}"'"}]
  }'
fi

SIGNUP_RESPONSE=$(curl -s -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  -d "${SIGNUP_DATA}")

echo "Sign-up response: ${SIGNUP_RESPONSE}"

# Wait for user to get verification code
echo ""
echo "=== Step 2: Confirm Sign Up ==="
read -p "Enter the verification code sent to your email: " VERIFICATION_CODE

if [ -n "$CLIENT_SECRET" ]; then
  SECRET_HASH=$(compute_secret_hash "$USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")
  CONFIRM_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "SecretHash": "'"${SECRET_HASH}"'",
    "Username": "'"${USERNAME}"'",
    "ConfirmationCode": "'"${VERIFICATION_CODE}"'"
  }'
else
  CONFIRM_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "Username": "'"${USERNAME}"'",
    "ConfirmationCode": "'"${VERIFICATION_CODE}"'"
  }'
fi

CONFIRM_RESPONSE=$(curl -s -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.ConfirmSignUp" \
  -d "${CONFIRM_DATA}")

echo "Confirmation response: ${CONFIRM_RESPONSE}"

echo ""
echo "=== Step 3: Sign In ==="

if [ -n "$CLIENT_SECRET" ]; then
  SECRET_HASH=$(compute_secret_hash "$USERNAME" "$CLIENT_ID" "$CLIENT_SECRET")
  SIGNIN_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "USER_PASSWORD_AUTH",
    "AuthParameters": {
      "USERNAME": "'"${USERNAME}"'",
      "PASSWORD": "'"${PASSWORD}"'",
      "SECRET_HASH": "'"${SECRET_HASH}"'"
    }
  }'
else
  SIGNIN_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "USER_PASSWORD_AUTH",
    "AuthParameters": {
      "USERNAME": "'"${USERNAME}"'",
      "PASSWORD": "'"${PASSWORD}"'"
    }
  }'
fi

SIGNIN_RESPONSE=$(curl -s -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d "${SIGNIN_DATA}")

echo "Sign-in response: ${SIGNIN_RESPONSE}"

# Extract tokens
REFRESH_TOKEN=$(echo $SIGNIN_RESPONSE | jq -r '.AuthenticationResult.RefreshToken')
ID_TOKEN=$(echo $SIGNIN_RESPONSE | jq -r '.AuthenticationResult.IdToken')
ACCESS_TOKEN=$(echo $SIGNIN_RESPONSE | jq -r '.AuthenticationResult.AccessToken')

echo ""
echo "Tokens received:"
echo "- Access Token: ${ACCESS_TOKEN:0:50}..."
echo "- ID Token: ${ID_TOKEN:0:50}..."
echo "- Refresh Token: ${REFRESH_TOKEN:0:50}..."

echo ""
echo "=== Step 4: Refresh Tokens ==="

if [ -n "$CLIENT_SECRET" ]; then
  # Extract sub from ID token for secret hash
  USER_SUB=$(echo $ID_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.sub')
  SECRET_HASH=$(compute_secret_hash "$USER_SUB" "$CLIENT_ID" "$CLIENT_SECRET")
  
  REFRESH_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "REFRESH_TOKEN_AUTH",
    "AuthParameters": {
      "REFRESH_TOKEN": "'"${REFRESH_TOKEN}"'",
      "SECRET_HASH": "'"${SECRET_HASH}"'"
    }
  }'
else
  REFRESH_DATA='{
    "ClientId": "'"${CLIENT_ID}"'",
    "AuthFlow": "REFRESH_TOKEN_AUTH",
    "AuthParameters": {
      "REFRESH_TOKEN": "'"${REFRESH_TOKEN}"'"
    }
  }'
fi

REFRESH_RESPONSE=$(curl -s -X POST "${COGNITO_ENDPOINT}" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d "${REFRESH_DATA}")

echo "Token refresh response: ${REFRESH_RESPONSE}"

echo ""
echo "=== Testing Complete ==="
```

---

## References

### AWS Documentation

- [Amazon Cognito Authentication](https://docs.aws.amazon.com/cognito/latest/developerguide/authentication.html)
- [SignUp API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_SignUp.html)
- [ConfirmSignUp API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ConfirmSignUp.html)
- [InitiateAuth API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_InitiateAuth.html)
- [Refresh Tokens](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-refresh-token.html)
- [Computing Secret Hash Values](https://docs.aws.amazon.com/cognito/latest/developerguide/signing-up-users-in-your-app.html#cognito-user-pools-computing-secret-hash)

### Additional Resources

- [AWS Knowledge Center - Unable to verify secret hash](https://aws.amazon.com/premiumsupport/knowledge-center/cognito-unable-to-verify-secret-hash/)
- [Cognito User Pool API Operations](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pools-API-operations.html)

---

## Summary

This guide provides a complete reference for testing Amazon Cognito User Pools authentication using CURL commands. Key takeaways:

1. **User Pool Client Configuration** is critical - ensure auth flows are enabled
2. **SECRET_HASH** is required when your client has a Client Secret
3. **Token lifecycle** management is essential for production applications
4. **Refresh tokens** enable seamless user experience without re-authentication
5. **Error handling** helps debug authentication issues quickly

Use this guide alongside your Terraform infrastructure to validate your Cognito setup and understand the authentication flow at the API level.
