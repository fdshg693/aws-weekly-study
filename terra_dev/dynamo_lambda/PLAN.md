# DynamoDB + API Gateway + Lambda - 実装プラン

## 概要

API Gateway + Lambda + DynamoDB を使ったサーバーレスCRUD APIを構築する。
REST APIでアイテムの作成・取得・更新・削除ができるシンプルなAPIを実装し、サーバーレスアーキテクチャの基本パターンを学ぶ。

## アーキテクチャ

```
クライアント
  ↓ HTTP リクエスト
API Gateway (REST API)
  ↓ プロキシ統合
Lambda関数 (Python)
  ↓ CRUD操作
DynamoDB テーブル
```

## 技術スタック

- **API Gateway (REST API)**: HTTPリクエストを受け付けるエンドポイント
- **Lambda (Python 3.12)**: ビジネスロジックの実行
- **DynamoDB**: NoSQLデータベースによるデータ永続化
- **IAM**: Lambda → DynamoDB へのアクセス制御
- **CloudWatch Logs**: Lambda関数のログ出力

## 作成物

- `/items` エンドポイントに対してCRUD操作ができるREST API
  - `GET /items` : アイテム一覧取得
  - `GET /items/{id}` : アイテム個別取得
  - `POST /items` : アイテム作成
  - `PUT /items/{id}` : アイテム更新
  - `DELETE /items/{id}` : アイテム削除

## 構成ファイル（予定）

```
dynamo_lambda/
├── PLAN.md              # 本ファイル（実装プラン）
├── README.md            # プロジェクト説明
├── provider.tf          # AWSプロバイダ設定
├── variables.tf         # 変数定義
├── dynamodb.tf          # DynamoDBテーブル定義
├── lambda.tf            # Lambda関数定義
├── api_gateway.tf       # API Gateway定義
├── iam.tf               # IAMロール・ポリシー定義
├── outputs.tf           # 出力定義（APIエンドポイントURL等）
├── dev.tfvars           # 開発環境用変数
├── prod.tfvars          # 本番環境用変数
└── src/
    └── lambda_function.py  # Lambda関数コード（CRUD処理）
```

## 実装ステップ

### Step 1: 基盤構築

- `provider.tf` : AWSプロバイダ設定（ap-northeast-1、default_tags）
- `variables.tf` : プロジェクト名、環境、リージョン等の変数定義
- `dev.tfvars` / `prod.tfvars` : 環境ごとの値

### Step 2: DynamoDB テーブル

- `dynamodb.tf` で以下を定義:
  - テーブル名: `${project_name}-items-${environment}`
  - パーティションキー: `id` (String)
  - 課金モード: PAY_PER_REQUEST（オンデマンド、開発向け）
  - TTL設定: 不要（シンプルに保つ）

### Step 3: Lambda関数

- `src/lambda_function.py` : CRUDハンドラを実装
  - API Gatewayプロキシ統合に対応したリクエスト/レスポンス形式
  - httpMethod と resource でルーティング
  - boto3 で DynamoDB を操作
  - エラーハンドリング（404、400、500）
- `lambda.tf` : Lambda関数リソース定義
  - archive_file でソースコードをZIP化
  - 環境変数に DynamoDB テーブル名を渡す

### Step 4: IAM

- `iam.tf` で以下を定義:
  - Lambda実行ロール（AssumeRole: lambda.amazonaws.com）
  - AWSLambdaBasicExecutionRole（CloudWatch Logs用）
  - DynamoDB操作用カスタムポリシー（GetItem, PutItem, UpdateItem, DeleteItem, Scan）
  - 対象リソースはテーブルARNに限定（最小権限の原則）

### Step 5: API Gateway

- `api_gateway.tf` で以下を定義:
  - REST API の作成
  - `/items` リソースと `/{id}` 子リソース
  - 各HTTPメソッド（GET, POST, PUT, DELETE）の定義
  - Lambda プロキシ統合（AWS_PROXY）
  - デプロイメントとステージ（dev / prod）
  - Lambda の invoke 権限（aws_lambda_permission）

### Step 6: 出力とテスト

- `outputs.tf` : APIエンドポイントURL、DynamoDBテーブル名、Lambda関数名を出力
- README.md に curl でのテスト例を記載

## 学習ポイント

1. **API Gateway + Lambda統合**: プロキシ統合によるリクエスト/レスポンスのマッピング
2. **DynamoDB の基本操作**: パーティションキー設計、CRUD操作（boto3）
3. **IAM最小権限**: 必要な操作・リソースのみに限定したポリシー設計
4. **サーバーレスパターン**: API Gateway → Lambda → DynamoDB の王道構成

## 注意事項

- API Gatewayのデプロイには明示的な `aws_api_gateway_deployment` が必要（リソース変更時の再デプロイに注意）
- DynamoDB の PAY_PER_REQUEST はリクエスト量が少ない開発環境向け（本番は PROVISIONED も検討）
- Lambda関数のコールドスタートに注意（Python は比較的軽量）
- API Gateway のステージ変数やスロットリングは今回はスコープ外とする
