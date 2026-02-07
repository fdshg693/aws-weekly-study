# Cognito Quick Reference
# =======================
# よく使うコマンドとAPIコールのチートシート

## Terraform コマンド

### 初期化
terraform init

### フォーマット確認
terraform fmt

### 検証
terraform validate

### デプロイ（開発環境）
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"

### デプロイ（本番環境）
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"

### 削除
terraform destroy -var-file="dev.tfvars"

### 出力値の確認
terraform output
terraform output -json

## 環境変数設定

### 一括設定スクリプト
```bash
export REGION=$(terraform output -raw aws_region)
export USER_POOL_ID=$(terraform output -raw user_pool_id)
export CLIENT_ID=$(terraform output -raw user_pool_client_id)
export TEST_EMAIL="test@example.com"
export TEST_PASSWORD="TestPass123!"
```

## AWS CLI コマンド

### 1. ユーザー登録
```bash
aws cognito-idp sign-up \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --password $TEST_PASSWORD \
  --user-attributes Name=email,Value=$TEST_EMAIL Name=name,Value="Test User"
```

### 2. メール検証（管理者）
```bash
aws cognito-idp admin-confirm-sign-up \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL
```

### 3. メール検証（ユーザー）
```bash
aws cognito-idp confirm-sign-up \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --confirmation-code "123456"
```

### 4. ログイン
```bash
aws cognito-idp initiate-auth \
  --region $REGION \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD
```

### 5. ユーザー情報取得
```bash
aws cognito-idp get-user \
  --region $REGION \
  --access-token $ACCESS_TOKEN
```

### 6. トークンリフレッシュ
```bash
aws cognito-idp initiate-auth \
  --region $REGION \
  --auth-flow REFRESH_TOKEN_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters REFRESH_TOKEN=$REFRESH_TOKEN
```

### 7. パスワード変更
```bash
aws cognito-idp change-password \
  --region $REGION \
  --previous-password $TEST_PASSWORD \
  --proposed-password "NewPassword123!" \
  --access-token $ACCESS_TOKEN
```

### 8. パスワードリセット開始
```bash
aws cognito-idp forgot-password \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL
```

### 9. パスワードリセット確認
```bash
aws cognito-idp confirm-forgot-password \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --confirmation-code "123456" \
  --password "NewPassword123!"
```

### 10. ログアウト
```bash
aws cognito-idp global-sign-out \
  --region $REGION \
  --access-token $ACCESS_TOKEN
```

## 管理者コマンド

### ユーザー作成（管理者）
```bash
aws cognito-idp admin-create-user \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL \
  --user-attributes Name=email,Value=$TEST_EMAIL Name=name,Value="Test User" \
  --message-action SUPPRESS
```

### ユーザー削除
```bash
aws cognito-idp admin-delete-user \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL
```

### ユーザー一覧
```bash
aws cognito-idp list-users \
  --region $REGION \
  --user-pool-id $USER_POOL_ID
```

### ユーザー無効化
```bash
aws cognito-idp admin-disable-user \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL
```

### ユーザー有効化
```bash
aws cognito-idp admin-enable-user \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL
```

### パスワードリセット（管理者）
```bash
aws cognito-idp admin-set-user-password \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL \
  --password "NewPassword123!" \
  --permanent
```

### ユーザー属性更新（管理者）
```bash
aws cognito-idp admin-update-user-attributes \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL \
  --user-attributes Name=name,Value="Updated Name"
```

## CURL コマンド（直接API呼び出し）

### エンドポイント設定
```bash
export COGNITO_ENDPOINT="https://cognito-idp.$REGION.amazonaws.com"
```

### サインアップ
```bash
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  --data "{
    \"ClientId\": \"$CLIENT_ID\",
    \"Username\": \"$TEST_EMAIL\",
    \"Password\": \"$TEST_PASSWORD\",
    \"UserAttributes\": [
      {\"Name\": \"email\", \"Value\": \"$TEST_EMAIL\"},
      {\"Name\": \"name\", \"Value\": \"Test User\"}
    ]
  }" \
  $COGNITO_ENDPOINT/
```

### ログイン
```bash
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  --data "{
    \"ClientId\": \"$CLIENT_ID\",
    \"AuthFlow\": \"USER_PASSWORD_AUTH\",
    \"AuthParameters\": {
      \"USERNAME\": \"$TEST_EMAIL\",
      \"PASSWORD\": \"$TEST_PASSWORD\"
    }
  }" \
  $COGNITO_ENDPOINT/
```

## JWTトークンのデコード

### IDトークンのデコード
```bash
echo $ID_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

### アクセストークンのデコード
```bash
echo $ACCESS_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

### トークンの有効期限確認
```bash
echo $ID_TOKEN | cut -d'.' -f2 | base64 -d | jq '.exp' | xargs -I {} date -r {}
```

## トラブルシューティング

### User Pool情報の確認
```bash
aws cognito-idp describe-user-pool \
  --region $REGION \
  --user-pool-id $USER_POOL_ID
```

### User Pool Client情報の確認
```bash
aws cognito-idp describe-user-pool-client \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID
```

### エラーログの確認
CloudWatch Logsでエラーを確認（Lambda Triggerを使用している場合）

## 自動テストスクリプト

### 認証フロー完全テスト
```bash
chmod +x test_auth_flow.sh
./test_auth_flow.sh
```

## Tips

### 複数ユーザーの一括作成
```bash
for i in {1..10}; do
  aws cognito-idp admin-create-user \
    --region $REGION \
    --user-pool-id $USER_POOL_ID \
    --username "user${i}@example.com" \
    --user-attributes Name=email,Value="user${i}@example.com" \
    --message-action SUPPRESS
done
```

### 全ユーザーの削除
```bash
aws cognito-idp list-users \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --query 'Users[].Username' \
  --output text | tr '\t' '\n' | while read username; do
    echo "Deleting $username"
    aws cognito-idp admin-delete-user \
      --region $REGION \
      --user-pool-id $USER_POOL_ID \
      --username "$username"
done
```

## 参考リンク

- [Cognito User Pool API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/)
- [AWS CLI Cognito IDP Commands](https://docs.aws.amazon.com/cli/latest/reference/cognito-idp/)
- [JWT.io - Token Decoder](https://jwt.io/)
