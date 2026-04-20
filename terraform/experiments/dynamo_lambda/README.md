# DynamoDB + API Gateway + Lambda - サーバーレスCRUD API

## 概要

API Gateway + Lambda + DynamoDB を使ったサーバーレスCRUD APIの実験プロジェクト。
REST APIでアイテムの作成・取得・更新・削除ができるシンプルなAPIを実装し、サーバーレスアーキテクチャの基本パターンを学ぶ。

## アーキテクチャ

```
クライアント
  ↓ HTTP リクエスト
API Gateway (REST API)
  ↓ プロキシ統合
Lambda関数 (Python 3.12)
  ↓ CRUD操作
DynamoDB テーブル
```

## エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | /items | アイテム一覧取得 |
| GET | /items/{id} | アイテム個別取得 |
| POST | /items | アイテム作成 |
| PUT | /items/{id} | アイテム更新 |
| DELETE | /items/{id} | アイテム削除 |

## ファイル構成

```
dynamo_lambda/
├── PLAN.md              # 実装プラン
├── README.md            # 本ファイル
├── provider.tf          # AWSプロバイダ設定
├── variables.tf         # 変数定義
├── dynamodb.tf          # DynamoDBテーブル定義
├── lambda.tf            # Lambda関数定義
├── api_gateway.tf       # API Gateway定義
├── iam.tf               # IAMロール・ポリシー定義
├── outputs.tf           # 出力定義
├── dev.tfvars           # 開発環境用変数
├── prod.tfvars          # 本番環境用変数
└── src/
    └── lambda_function.py  # Lambda関数コード
```

## デプロイ手順

### 1. 初期化

```bash
terraform init
```

### 2. プランの確認

```bash
# 開発環境
terraform plan -var-file=dev.tfvars

# 本番環境
terraform plan -var-file=prod.tfvars
```

### 3. デプロイ

```bash
# 開発環境
terraform apply -var-file=dev.tfvars

# 本番環境
terraform apply -var-file=prod.tfvars
```

### 4. エンドポイントの確認

```bash
terraform output api_endpoint
```

## テスト方法

デプロイ後、`terraform output test_commands` でcurlコマンドの一覧を確認できる。

### アイテム作成

```bash
API_URL=$(terraform output -raw api_endpoint)

curl -X POST ${API_URL}/items \
  -H "Content-Type: application/json" \
  -d '{"name": "テストアイテム", "description": "テスト用の説明"}'
```

### アイテム一覧取得

```bash
curl -X GET ${API_URL}/items
```

### アイテム個別取得

```bash
curl -X GET ${API_URL}/items/{id}
```

### アイテム更新

```bash
curl -X PUT ${API_URL}/items/{id} \
  -H "Content-Type: application/json" \
  -d '{"name": "更新アイテム", "description": "更新された説明"}'
```

### アイテム削除

```bash
curl -X DELETE ${API_URL}/items/{id}
```

## クリーンアップ

```bash
terraform destroy -var-file=dev.tfvars
```

## 学習ポイント

1. **API Gateway + Lambda統合**: プロキシ統合によるリクエスト/レスポンスのマッピング
2. **DynamoDB の基本操作**: パーティションキー設計、CRUD操作（boto3）
3. **IAM最小権限**: 必要な操作・リソースのみに限定したポリシー設計
4. **サーバーレスパターン**: API Gateway → Lambda → DynamoDB の王道構成
