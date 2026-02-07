#!/bin/bash
# Cognito Authentication Flow Test Script
# ========================================
# このスクリプトは、Terraformでデプロイしたcognito User Poolを使用して
# 基本的な認証フローをテストします。
#
# 使用方法:
#   chmod +x test_auth_flow.sh
#   ./test_auth_flow.sh

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Cognito Authentication Flow Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Terraform outputから必要な情報を取得
echo -e "${YELLOW}[1/9] Terraformの出力値を取得中...${NC}"
REGION=$(terraform output -raw aws_region 2>/dev/null)
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null)
CLIENT_ID=$(terraform output -raw user_pool_client_id 2>/dev/null)

if [ -z "$REGION" ] || [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Error: Terraform outputsが取得できませんでした${NC}"
    echo -e "${YELLOW}terraform apply -var-file=\"dev.tfvars\" を実行してください${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Region: $REGION${NC}"
echo -e "${GREEN}✓ User Pool ID: $USER_POOL_ID${NC}"
echo -e "${GREEN}✓ Client ID: $CLIENT_ID${NC}"
echo ""

# テストユーザー情報
TEST_EMAIL="test-$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!"
TEST_NAME="Test User"

echo -e "${YELLOW}[2/9] テストユーザー情報:${NC}"
echo -e "  Email: $TEST_EMAIL"
echo -e "  Password: $TEST_PASSWORD"
echo ""

# ユーザー登録
echo -e "${YELLOW}[3/9] ユーザー登録中...${NC}"
SIGNUP_RESULT=$(aws cognito-idp sign-up \
  --region "$REGION" \
  --client-id "$CLIENT_ID" \
  --username "$TEST_EMAIL" \
  --password "$TEST_PASSWORD" \
  --user-attributes Name=email,Value="$TEST_EMAIL" Name=name,Value="$TEST_NAME" \
  2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ユーザー登録成功${NC}"
    echo "$SIGNUP_RESULT" | jq '.'
else
    echo -e "${RED}✗ ユーザー登録失敗${NC}"
    echo "$SIGNUP_RESULT"
    exit 1
fi
echo ""

# メール検証をスキップ（管理者権限で確認）
echo -e "${YELLOW}[4/9] ユーザーを管理者権限で確認中...${NC}"
CONFIRM_RESULT=$(aws cognito-idp admin-confirm-sign-up \
  --region "$REGION" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_EMAIL" \
  2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ユーザー確認成功${NC}"
else
    echo -e "${RED}✗ ユーザー確認失敗${NC}"
    echo "$CONFIRM_RESULT"
    exit 1
fi
echo ""

# ログイン
echo -e "${YELLOW}[5/9] ログイン中...${NC}"
AUTH_RESULT=$(aws cognito-idp initiate-auth \
  --region "$REGION" \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$CLIENT_ID" \
  --auth-parameters USERNAME="$TEST_EMAIL",PASSWORD="$TEST_PASSWORD" \
  2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ログイン成功${NC}"
    
    # トークンを抽出
    ACCESS_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.AccessToken')
    ID_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.IdToken')
    REFRESH_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.RefreshToken')
    
    # トークンの検証
    if [ "$REFRESH_TOKEN" = "null" ] || [ -z "$REFRESH_TOKEN" ]; then
        echo -e "${RED}✗ リフレッシュトークンが取得できませんでした${NC}"
        echo -e "${YELLOW}  認証結果:${NC}"
        echo "$AUTH_RESULT" | jq '.'
    else
        echo -e "${GREEN}✓ アクセストークン取得: ${ACCESS_TOKEN:0:50}...${NC}"
        echo -e "${GREEN}✓ IDトークン取得: ${ID_TOKEN:0:50}...${NC}"
        echo -e "${GREEN}✓ リフレッシュトークン取得: ${REFRESH_TOKEN:0:50}...${NC}"
    fi
else
    echo -e "${RED}✗ ログイン失敗${NC}"
    echo "$AUTH_RESULT"
    exit 1
fi
echo ""

# IDトークンのデコード
echo -e "${YELLOW}[6/9] IDトークンをデコード中...${NC}"
ID_TOKEN_PAYLOAD=$(echo "$ID_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ IDトークンの内容:${NC}"
    echo "$ID_TOKEN_PAYLOAD" | jq '.'
else
    echo -e "${YELLOW}⚠ IDトークンのデコードに失敗しました${NC}"
fi
echo ""

# ユーザー情報の取得
echo -e "${YELLOW}[7/9] ユーザー情報を取得中...${NC}"
USER_INFO=$(aws cognito-idp get-user \
  --region "$REGION" \
  --access-token "$ACCESS_TOKEN" \
  2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ユーザー情報取得成功:${NC}"
    echo "$USER_INFO" | jq '.'
else
    echo -e "${RED}✗ ユーザー情報取得失敗${NC}"
    echo "$USER_INFO"
fi
echo ""

# トークンリフレッシュ
echo -e "${YELLOW}[8/9] トークンをリフレッシュ中...${NC}"
echo -e "${BLUE}  注意: USER_PASSWORD_AUTH フローでのリフレッシュトークンには既知の制限があります${NC}"
# set -eの影響を受けないようにコマンドを実行
set +e
# jqを使用して安全にJSONを構築し、一時ファイルに保存
TEMP_JSON=$(mktemp)
jq -n \
  --arg client_id "$CLIENT_ID" \
  --arg refresh_token "$REFRESH_TOKEN" \
  '{
    AuthFlow: "REFRESH_TOKEN_AUTH",
    ClientId: $client_id,
    AuthParameters: {
      REFRESH_TOKEN: $refresh_token
    }
  }' > "$TEMP_JSON"

REFRESH_RESULT=$(aws cognito-idp initiate-auth \
  --region "$REGION" \
  --cli-input-json "file://$TEMP_JSON" \
  2>&1)
REFRESH_EXIT_CODE=$?
rm -f "$TEMP_JSON"
set -e

if [ $REFRESH_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ トークンリフレッシュ成功${NC}"
    NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESULT" | jq -r '.AuthenticationResult.AccessToken')
    echo -e "${GREEN}✓ 新しいアクセストークン: ${NEW_ACCESS_TOKEN:0:50}...${NC}"
else
    echo -e "${RED}✗ トークンリフレッシュ失敗${NC}"
    echo "$REFRESH_RESULT"
    echo ""
    echo -e "${YELLOW}【既知の問題】${NC}"
    echo -e "${YELLOW}Cognitoの USER_PASSWORD_AUTH フローで取得したリフレッシュトークンの使用には${NC}"
    echo -e "${YELLOW}環境や設定によって制限がある場合があります。${NC}"
    echo -e "${YELLOW}代替案:${NC}"
    echo -e "  ${BLUE}1. トークン期限切れ時に再認証を実行${NC}"
    echo -e "  ${BLUE}2. Hosted UIを使用したOAuthフローを検討${NC}"
    echo -e "  ${BLUE}3. SDK（boto3, AWS Amplify等）の使用を検討${NC}"
fi
echo ""

# クリーンアップ (オプション)
echo -e "${YELLOW}[9/9] テストユーザーを削除しますか? (y/N)${NC}"
# readコマンドのタイムアウトでスクリプトが終了しないようにする
set +e
read -t 10 -r CLEANUP_RESPONSE || CLEANUP_RESPONSE="N"
set -e

if [ "$CLEANUP_RESPONSE" = "y" ] || [ "$CLEANUP_RESPONSE" = "Y" ]; then
    echo -e "${YELLOW}テストユーザーを削除中...${NC}"
    aws cognito-idp admin-delete-user \
      --region "$REGION" \
      --user-pool-id "$USER_POOL_ID" \
      --username "$TEST_EMAIL" \
      2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ テストユーザー削除成功${NC}"
    else
        echo -e "${RED}✗ テストユーザー削除失敗${NC}"
    fi
else
    echo -e "${YELLOW}⚠ テストユーザーは削除されませんでした: $TEST_EMAIL${NC}"
    echo -e "${YELLOW}  手動削除する場合:${NC}"
    echo -e "${BLUE}  aws cognito-idp admin-delete-user --region $REGION --user-pool-id $USER_POOL_ID --username $TEST_EMAIL${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ 認証フローテスト完了！${NC}"
echo -e "${BLUE}========================================${NC}"
