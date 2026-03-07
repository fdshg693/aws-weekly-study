# AWS Cognito Authentication Infrastructure

## 概要
TerraformでAWS Cognitoユーザープールを構築し、BFF（Backend For Frontend）パターンによるセキュアな認証基盤を実装します。フロントエンド（Vue 3 SPA）からトークンを隠蔽し、サーバーサイドでOAuth 2.0 + OIDC認証フローを処理する、学習・実験用のインフラストラクチャです。

### アーキテクチャ
```
[Vue 3 SPA]  ──→  [BFF (Express/Lambda)]  ──→  [Cognito User Pool]
 (Amplify)          (API Gateway)                  (Hosted UI)
                         │
                    [DynamoDB]
                   (セッション管理)
```

### 技術スタック
- **Terraform** v1.0+ - インフラストラクチャプロビジョニング
- **AWS Cognito** - ユーザー認証・認可サービス
- **AWS Lambda** (Node.js 20.x) - BFFサーバー（Express + serverless-http）
- **API Gateway HTTP API v2** - BFF APIエンドポイント
- **DynamoDB** - セッション・認証状態の永続化
- **AWS Amplify Hosting** - Vue SPAの静的サイトホスティング
- **Vue 3 + Vite** - フロントエンドSPA

### 作成物
デプロイ完了後、以下の環境が構築されます：

| リソース | 説明 |
|----------|------|
| **Cognito User Pool** | ユーザーディレクトリ、パスワードポリシー、MFA設定 |
| **User Pool Client** | Confidential Client（client_secret付き） |
| **User Pool Domain** | Hosted UIアクセス用ドメイン |
| **Lambda Function** | BFFサーバー（Express、認証エンドポイント） |
| **API Gateway HTTP API** | Lambda統合、CORS設定済み |
| **DynamoDB Table** | セッションストア（TTL自動削除） |
| **IAM Role** | Lambda実行ロール（DynamoDB CRUD権限） |
| **Amplify Hosting** | Vue SPAの静的サイトホスティング |

## 認証フロー

```
[ブラウザ] → GET /auth/login → [BFF]
                                  │ PKCE(code_verifier/challenge) + state + nonce 生成
                                  │ DynamoDBに保存
                                  ↓
                            302 → [Cognito Hosted UI]
                                  │ ユーザーがログイン
                                  ↓
                            302 → [BFF] GET /auth/callback?code=xxx&state=yyy
                                  │ state検証
                                  │ code + code_verifier + client_secretでトークン取得
                                  │ JWT署名検証（JWKS）、nonce検証
                                  │ セッション作成 → DynamoDB保存
                                  │ HttpOnlyクッキー設定
                                  ↓
                            302 → [ブラウザ] ログイン完了
                                  │ GET /auth/me でユーザー情報取得
```

## 構成ファイル

### Terraformファイル
| ファイル | 説明 |
|----------|------|
| **provider.tf** | AWSプロバイダー設定 |
| **variables.tf** | 変数定義（30+パラメータ） |
| **cognito.tf** | User Pool、Client、Domain |
| **lambda.tf** | Lambda、API Gateway、DynamoDB、IAMロール |
| **amplify.tf** | Amplify Hosting、config.json生成 |
| **outputs.tf** | 出力値（URL、ID、テストコマンド等） |
| **dev.tfvars / prod.tfvars** | 環境別変数 |

### BFF（`bff/`）- Express + Lambda
| ファイル | 説明 |
|----------|------|
| **server.js** | Express開発サーバー（ローカル用） |
| **lambda.js** | Lambdaハンドラー（serverless-http） |
| **config.js** | 設定管理（Terraform生成 or 環境変数） |
| **auth/routes.js** | 認証エンドポイント（/login, /callback, /logout, /me, /refresh） |
| **auth/cognito.js** | Cognito OAuth連携（PKCE + state + nonce） |
| **auth/session.js** | セッション管理（CRUD） |
| **auth/sessionStore.js** | ストアファクトリ（memory / DynamoDB切替） |
| **auth/jwt.js** | JWT署名検証（jose + JWKS） |
| **auth/csrf.js** | CSRF対策（Double Submit Cookie） |
| **stores/memoryStore.js** | インメモリストア（ローカル開発用） |
| **stores/dynamodbStore.js** | DynamoDBストア（Lambda本番用） |

### フロントエンド（`frontend/`）
| ファイル | 説明 |
|----------|------|
| **src/auth/cognito.js** | BFF APIクライアント |
| **src/auth/pkce.js** | PKCE実装（参考用、BFFでは未使用） |
| **src/auth/tokenStore.js** | トークン管理（参考用、BFFでは未使用） |
| **src/components/** | LoginButton, LogoutButton, UserInfo, TokenDetails |

### テスト・ドキュメント
- **test_auth_flow.sh** - E2E認証フローテスト
- **セキュリティ対策.md** - セキュリティ脆弱性分析と対策

## セキュリティ対策

BFFパターンにより、以下のセキュリティを実装済み：

| 対策 | 実装 |
|------|------|
| **トークン隠蔽** | HttpOnlyクッキー + サーバーサイド保管（XSS対策） |
| **PKCE (RFC 7636)** | 認可コード横取り攻撃の防止 |
| **State パラメータ** | ログインCSRF攻撃の防止 |
| **Nonce (OIDC)** | トークンリプレイ攻撃の防止 |
| **JWT署名検証** | JWKS（RS256）による署名・有効期限・発行者・対象者検証 |
| **CSRF保護** | Double Submit Cookieパターン |

## デプロイ手順

### 1. 初期化・デプロイ
```bash
make init     # Terraform初期化
make plan     # 計画確認
make apply    # デプロイ（BFFパッケージング + Terraform + フロントエンド自動デプロイ）
```

### 2. 出力値の確認
```bash
make output
```

### 初回デプロイ時の注意
初回はAmplify URL・API Gateway URLが未確定のため、以下の手順が必要です：
1. `make apply` でインフラ作成（URL確定）
2. 出力されたURLを `dev.tfvars` の `callback_urls` / `logout_urls` に追加
3. 再度 `make apply` でcallback URLs更新 + フロントエンド再デプロイ

### ローカル開発
```bash
# ターミナル1: BFFサーバー（:3000）
make bff-dev

# ターミナル2: フロントエンド（:5173）
make frontend-dev

# ブラウザ: http://localhost:5173
# ※ Viteプロキシにより /auth/* は自動的にBFF(:3000)に転送
```

### その他のコマンド
```bash
make help           # 全コマンド一覧
make test           # E2E認証フローテスト
make bff-logs       # Lambda CloudWatchログ表示
make bff-invoke     # BFFヘルスチェック
make destroy        # リソース削除
```

## CURLを使用した直接APIコール

AWS CLIを使わず、CURLでCognito APIを直接呼び出すことも可能です。

### サインアップ
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

### ログイン
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
- [API Gateway HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/)

### Terraform公式ドキュメント
- [aws_cognito_user_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool)
- [aws_cognito_user_pool_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client)
- [aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [aws_apigatewayv2_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api)
- [aws_dynamodb_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table)

### 認証フロー・セキュリティ
- [OAuth 2.0 Authorization Code Flow with PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [BFF Security Pattern](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps)
