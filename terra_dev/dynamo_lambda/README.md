# DynamoDB + API Gateway + Lambda Prompt CRUD API

## 概要

`terra_dev/dynamo_lambda` は、API Gateway (REST API) + Lambda (Python 3.12) + DynamoDB を使って、AI プロンプト定義を管理するサーバーレス CRUD API を構築する Terraform サンプルです。

`GET /prompts` では共通 GSI を使った一覧取得を行い、`GET /prompts?tag=summary` ではタグ索引用アイテムを使って `Query` ベースで絞り込みます。`Scan` や `FilterExpression` 前提にしない、DynamoDB らしいアクセスパターン駆動の構成です。

## 作成される主なリソース

- DynamoDB テーブル: `${project_name}-prompts-${environment}`
- Lambda 関数: `${project_name}-prompts-api-${environment}`
- API Gateway REST API: `/prompts`, `/prompts/{id}`
- IAM ロール / ポリシー
- CloudWatch Logs

## ファイル構成

- `provider.tf` - AWS / archive プロバイダー設定
- `variables.tf` - 変数定義
- `dynamodb.tf` - Prompt テーブルと GSI
- `iam.tf` - Lambda 実行ロールと DynamoDB 権限
- `lambda.tf` - Lambda パッケージングと関数定義
- `api_gateway.tf` - REST API、メソッド、統合、CORS
- `outputs.tf` - API URL などの出力
- `src/lambda_function.py` - Prompt CRUD ハンドラ本体

## デプロイ手順

### 事前条件

- Terraform 1.5 以上
- AWS CLI 認証済み
- 対象リージョンで Lambda / API Gateway / DynamoDB を作成できる権限

### 開発環境へデプロイ

```bash
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 本番相当環境へデプロイ

```bash
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

### 削除

```bash
terraform destroy -var-file="dev.tfvars"
```

## API 利用例

まず API URL を取得します。

```bash
API_URL="$(terraform output -raw api_base_url)"
```

### Prompt 作成

```bash
curl -X POST "$API_URL/prompts" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "summary-assistant",
    "description": "長文を要約するためのプロンプト",
    "prompt_text": "以下の文章を3行で要約してください: {{input_text}}",
    "variables": ["input_text"],
    "tags": ["summary", "japanese"],
    "target_model": "gpt-4.1",
    "version": "v1",
    "is_active": true
  }'
```

### 一覧取得

```bash
curl "$API_URL/prompts"
```

### タグ絞り込み取得

```bash
curl "$API_URL/prompts?tag=summary"
```

### 個別取得

```bash
curl "$API_URL/prompts/<prompt-id>"
```

### 更新

```bash
curl -X PUT "$API_URL/prompts/<prompt-id>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "summary-assistant-v2",
    "description": "より厳密な要約プロンプト",
    "prompt_text": "以下の文章を箇条書き3点で要約してください: {{input_text}}",
    "variables": ["input_text"],
    "tags": ["summary", "bullet"],
    "target_model": "gpt-4.1",
    "version": "v2",
    "is_active": true
  }'
```

### 削除

```bash
curl -X DELETE "$API_URL/prompts/<prompt-id>"
```

## Lambda 実装メモ

- `POST /prompts` で Prompt 本体とタグ索引用アイテムを保存
- `GET /prompts` は `access_pattern_index` を `Query`
- `GET /prompts/{id}` は主キー `id` による `GetItem`
- `PUT /prompts/{id}` は本体を更新し、タグ索引アイテムを再同期
- `DELETE /prompts/{id}` は本体と関連タグ索引アイテムを削除
- `next_token` は `LastEvaluatedKey` を Base64 でエンコードしたカーソル

## 注意点

- 一覧 API はサマリ項目のみ返し、`prompt_text` は個別取得で返します
- タグは正規化のため小文字化・重複排除します
- API Gateway の `OPTIONS` メソッドと Lambda レスポンスの両方で CORS を扱います
- このサンプルは学習用のため認証・認可は未実装です