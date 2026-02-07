# AWS Cognito Authentication Infrastructure

## 概要
TerraformでAWS Cognitoユーザープールを構築し、API認証基盤を実装します。ユーザー登録、ログイン、トークンリフレッシュなどの認証フローをCURLコマンドでテストできる、学習・実験用のインフラストラクチャです。

### 技術スタック
- **Terraform** v1.0+ - インフラストラクチャプロビジョニング
- **AWS Cognito** - ユーザー認証・認可サービス
- **AWS CLI / CURL** - APIテストツール

### 作成物
デプロイ完了後、以下の環境が構築されます：
- **Cognito User Pool**: ユーザーディレクトリとパスワードポリシー
- **User Pool Client**: API認証用クライアント（USER_PASSWORD_AUTH有効）
- **User Pool Domain**: Hosted UIアクセス用ドメイン（オプション）

これにより、メールアドレスベースの認証システムが即座に利用可能になり、サインアップ、ログイン、トークンリフレッシュなどの認証フローをAPI経由でテストできます。

## 構成ファイル

### Terraformファイル
- **provider.tf** - AWSプロバイダー設定
- **variables.tf** - 変数定義（パスワードポリシー、トークン有効期限など）
- **cognito.tf** - Cognitoユーザープール、クライアント、ドメイン定義
- **outputs.tf** - User Pool ID、Client IDなどの出力値
- **dev.tfvars** - 開発環境用の変数値
- **PLAN.md** - プロジェクトの計画ドキュメント

## デプロイ手順

### 1. 初期化
```bash
cd /Users/seiwan/CodeRoot/AWS/aws-weekly-study/terraform/experiments/cognito
terraform init
```

### 2. 計画確認
```bash
terraform plan -var-file="dev.tfvars"
```

### 3. デプロイ
```bash
terraform apply -var-file="dev.tfvars"
```

### 4. 出力値の確認
```bash
terraform output
```

必要な情報（User Pool ID、Client ID、Region）が表示されます。これらをメモしてテストに使用してください。

## 認証フローのテスト

デプロイ後、以下のCURLコマンドで認証フローをテストできます。

### 環境変数の設定
```bash
# Terraform outputから値を取得
export REGION=$(terraform output -raw aws_region)
export USER_POOL_ID=$(terraform output -raw user_pool_id)
export CLIENT_ID=$(terraform output -raw user_pool_client_id)
export COGNITO_ENDPOINT=$(terraform output -raw cognito_idp_endpoint)

# テストユーザー情報
export TEST_EMAIL="test@example.com"
export TEST_PASSWORD="TestPass123!"
```

### 1. ユーザー登録（Sign Up）
```bash
aws cognito-idp sign-up \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --password $TEST_PASSWORD \
  --user-attributes Name=email,Value=$TEST_EMAIL Name=name,Value="Test User"
```

**期待される結果**: ユーザー作成成功、メール検証コードが送信されます。

### 2. メール検証（Confirm Sign Up）
```bash
# メールで受信した検証コードを指定
export VERIFICATION_CODE="123456"

aws cognito-idp confirm-sign-up \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --confirmation-code $VERIFICATION_CODE
```

### 3. ログイン（Initiate Auth）
```bash
aws cognito-idp initiate-auth \
  --region $REGION \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD \
  --query 'AuthenticationResult.[AccessToken,IdToken,RefreshToken]' \
  --output json | jq -r '.[]' > /tmp/cognito_tokens.txt
```

**期待される結果**: アクセストークン、IDトークン、リフレッシュトークンが取得できます。

トークンを環境変数に保存:
```bash
export ACCESS_TOKEN=$(sed -n '1p' /tmp/cognito_tokens.txt)
export ID_TOKEN=$(sed -n '2p' /tmp/cognito_tokens.txt)
export REFRESH_TOKEN=$(sed -n '3p' /tmp/cognito_tokens.txt)
```

### 4. トークンの検証
IDトークンのデコードと内容確認:
```bash
# jq を使ってJWTをデコード（base64デコードのみ、署名検証なし）
echo $ID_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
```

### 5. ユーザー情報の取得
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
export NEW_PASSWORD="NewTestPass456!"

aws cognito-idp change-password \
  --region $REGION \
  --previous-password $TEST_PASSWORD \
  --proposed-password $NEW_PASSWORD \
  --access-token $ACCESS_TOKEN
```

### 8. ユーザー属性の更新
```bash
aws cognito-idp update-user-attributes \
  --region $REGION \
  --access-token $ACCESS_TOKEN \
  --user-attributes Name=name,Value="Updated Test User"
```

## Hosted UIのテスト

User Pool Domainが作成されている場合、ブラウザでHosted UIにアクセスできます。

### Hosted UIのURLを取得
```bash
terraform output hosted_ui_url
```

ブラウザで上記URLにアクセスすると、Cognitoが提供するログインページが表示されます。

## CURLを使用した直接APIコール

AWS CLIを使わず、CURLでCognito APIを直接呼び出すことも可能です。

### サインアップ（CURL版）
```bash
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  --data '{
    "ClientId": "'$CLIENT_ID'",
    "Username": "'$TEST_EMAIL'",
    "Password": "'$TEST_PASSWORD'",
    "UserAttributes": [
      {"Name": "email", "Value": "'$TEST_EMAIL'"},
      {"Name": "name", "Value": "Test User"}
    ]
  }' \
  $COGNITO_ENDPOINT/
```

### ログイン（CURL版）
```bash
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  --data '{
    "ClientId": "'$CLIENT_ID'",
    "AuthFlow": "USER_PASSWORD_AUTH",
    "AuthParameters": {
      "USERNAME": "'$TEST_EMAIL'",
      "PASSWORD": "'$TEST_PASSWORD'"
    }
  }' \
  $COGNITO_ENDPOINT/ | jq .
```

## コードの特徴

### 1. 柔軟な変数設計
パスワードポリシー、トークン有効期限、MFA設定など、ほぼ全ての設定を変数化。環境（dev/prod）に応じて柔軟に調整可能です。

### 2. セキュリティベストプラクティス
- **メール検証**: 自動的にメールアドレスを検証
- **パスワードポリシー**: 強固なパスワード要件（カスタマイズ可能）
- **ユーザー存在チェック保護**: タイミング攻撃対策
- **MFAサポート**: オプショナルまたは必須に設定可能

### 3. 複数の認証フロー対応
- **USER_PASSWORD_AUTH**: サーバーサイドアプリ向け
- **USER_SRP_AUTH**: より安全なSRP認証
- **REFRESH_TOKEN_AUTH**: トークンリフレッシュ

### 4. Hosted UIサポート
オプションでUser Pool Domainを作成し、Cognitoが提供するログインUIを即座に利用可能。フロントエンド開発前の認証フロー確認に便利です。

### 5. 詳細なコメントと学習支援
各リソースに日本語の詳細なコメントを付与。設定オプションの意味、ベストプラクティス、代替案などを記載し、学習に役立つ構成としています。

### 6. 環境別の削除保護
本番環境では削除保護を有効化し、誤削除を防止。開発環境では無効化し、素早い作り直しが可能です。

## よくある設定のカスタマイズ

### パスワードポリシーの変更
`dev.tfvars`または`variables.tf`で以下を調整:
```hcl
minimum_password_length = 12  # より長いパスワードを要求
require_symbols        = true  # 記号を必須にする
```

### トークン有効期限の変更
```hcl
access_token_validity  = 2   # 2時間に延長
refresh_token_validity = 90  # 90日に延長
```

### MFAを必須にする
```hcl
mfa_configuration = "ON"
```

### 自己登録を無効化
```hcl
enable_self_registration = false
```

### カスタム属性の追加
`cognito.tf`のschemaブロックに追加:
```hcl
schema {
  name                = "phone_number"
  attribute_data_type = "String"
  required            = false
  mutable             = true
  
  string_attribute_constraints {
    min_length = 10
    max_length = 20
  }
}
```

## トラブルシューティング

### ユーザー登録時にメールが届かない
- Cognitoのデフォルトメール送信には制限があります
- 本格的な運用ではAmazon SESの設定を推奨
- SES設定例（`cognito.tf`に追加）:
```hcl
email_configuration {
  email_sending_account = "DEVELOPER"
  source_arn            = "arn:aws:ses:REGION:ACCOUNT_ID:identity/your-email@example.com"
}
```

### ドメインプレフィックスの競合エラー
User Pool Domainのprefixはグローバルで一意である必要があります。`dev.tfvars`でユニークなprefixを指定してください:
```hcl
domain_prefix = "my-unique-prefix-12345"
```

### トークンの有効期限が短すぎる
開発環境であれば、`dev.tfvars`で有効期限を長めに設定:
```hcl
access_token_validity  = 24  # 24時間
refresh_token_validity = 365 # 1年
```

## クリーンアップ

リソースを削除する場合:
```bash
terraform destroy -var-file="dev.tfvars"
```

**注意**: 本番環境では削除保護が有効になっています。削除する場合は、先に`deletion_protection`を`INACTIVE`に変更してapplyしてから、destroyを実行してください。

## 参考資料

### AWS公式ドキュメント
- [Amazon Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/)
- [Cognito User Pool API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/)

### Terraform公式ドキュメント
- [aws_cognito_user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool)
- [aws_cognito_user_pool_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client)
- [aws_cognito_user_pool_domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain)

### 認証フロー
- [User Pool Authentication Flow](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-authentication-flow.html)
- [Using Tokens with User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-with-identity-providers.html)

## ライセンス

このプロジェクトは学習・実験目的のサンプルコードです。自由に改変・利用してください。

## 次のステップ

このCognito基盤を使って、以下のような発展的な実験が可能です：

1. **Lambda Trigger**: PreSignUp、PostConfirmationなどのLambdaトリガーを追加
2. **API Gateway統合**: CognitoオーソライザーでAPIを保護
3. **フロントエンド統合**: React/VueアプリケーションからAmplify経由で認証
4. **ソーシャルログイン**: Google、Facebook、AppleのIDプロバイダー連携
5. **カスタムUI**: Hosted UIをカスタマイズ、またはSDKで独自UI実装
6. **高度なセキュリティ**: リスクベース認証、アダプティブ認証の設定

ぜひこの基盤をベースに、様々な認証機能を試してみてください！
