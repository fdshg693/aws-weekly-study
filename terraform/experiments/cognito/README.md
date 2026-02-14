# AWS Cognito Authentication Infrastructure

## 概要
TerraformでAWS Cognitoユーザープールを構築し、Vue 3 SPAによるログインアプリケーションとAPI認証基盤を実装します。ユーザー登録、ログイン、トークンリフレッシュなどの認証フローを、ブラウザ（Vue SPA）とCURLコマンドの両方でテストできる、学習・実験用のインフラストラクチャです。

### 技術スタック
- **Terraform** v1.0+ - インフラストラクチャプロビジョニング
- **AWS Cognito** - ユーザー認証・認可サービス
- **AWS Amplify Hosting** - Vue SPAの静的サイトホスティング
- **Vue 3 + Vite** - フロントエンドSPA（手動PKCE実装）
- **AWS CLI / CURL** - APIテストツール

### 作成物
デプロイ完了後、以下の環境が構築されます：
- **Cognito User Pool**: ユーザーディレクトリとパスワードポリシー
- **User Pool Client**: API認証用クライアント（USER_PASSWORD_AUTH有効）
- **User Pool Domain**: Hosted UIアクセス用ドメイン（オプション）
- **Amplify Hosting**: Vue SPAのホスティング基盤（手動デプロイ）
- **Vue 3 SPA**: PKCE認証フロー対応のログインアプリケーション

これにより、メールアドレスベースの認証システムが即座に利用可能になり、サインアップ、ログイン、トークンリフレッシュなどの認証フローをブラウザおよびAPI経由でテストできます。

## 構成ファイル

### Terraformファイル
- **provider.tf** - AWSプロバイダー設定
- **variables.tf** - 変数定義（パスワードポリシー、トークン有効期限など）
- **cognito.tf** - Cognitoユーザープール、クライアント、ドメイン定義
- **amplify.tf** - Amplify Hostingリソースとfrontend設定ファイル生成
- **outputs.tf** - User Pool ID、Client ID、デプロイURL等の出力値
- **dev.tfvars** - 開発環境用の変数値

### フロントエンド（`frontend/`）
- **Vue 3 + Vite** によるSPA
- `src/auth/pkce.js` - PKCE（RFC 7636）のcode_verifier/code_challenge生成（Web Crypto API）
- `src/auth/cognito.js` - Cognito OAuthエンドポイント（authorize, token, logout）
- `src/auth/tokenStore.js` - sessionStorageベースのトークン管理 + JWTデコード
- `src/components/` - LoginButton, LogoutButton, UserInfo, TokenDetails
- aws-amplify SDKを使わず手動でPKCEを実装（教育目的）

### テスト
- **test_auth_flow.sh** - E2E認証フローテスト（sign-up, login, token refresh等）

## デプロイ手順

### 1. 初期化
```bash
make init
```

### 2. 計画確認・デプロイ
```bash
make plan    # 計画確認
make apply   # デプロイ（Amplifyへのフロントエンドデプロイも自動実行）
```

### 3. 出力値の確認
```bash
make output
```

デプロイされたURL（Amplify SPA、Hosted UI）や認証情報が表示されます。

### 初回デプロイ時の注意
初回はAmplify URLが未確定のため、以下の手順が必要です：
1. `make apply` でインフラ作成（Amplify URL確定）
2. 出力されたAmplify URLを `dev.tfvars` の `callback_urls` / `logout_urls` に追加
3. 再度 `make apply` でcallback URLs更新 + フロントエンドデプロイ

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

## 次のステップ

このCognito基盤を使って、以下のような発展的な実験が可能です：

1. **Lambda Trigger**: PreSignUp、PostConfirmationなどのLambdaトリガーを追加
2. **API Gateway統合**: CognitoオーソライザーでAPIを保護
3. **ソーシャルログイン**: Google、Facebook、AppleのIDプロバイダー連携
4. **高度なセキュリティ**: リスクベース認証、アダプティブ認証の設定
