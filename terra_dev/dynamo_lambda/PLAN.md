# DynamoDB + API Gateway + Lambda - 実装プラン

## 概要

API Gateway + Lambda + DynamoDB を使って、**AI に渡すプロンプト定義を管理するサーバーレス CRUD API** を構築する。
単なる汎用 item 管理ではなく、**prompt 本文・説明・変数・タグ・利用対象モデルなどを持つ「AIプロンプト」** を登録・取得・更新・削除できる API を実装し、サーバーレス構成と DynamoDB を使ったドメイン設計を学ぶ。

また、`GET /prompts` では単純な全件取得だけでなく、**タグによる一覧絞り込み**もできるようにし、
Lambda 側で全件取得後にフィルタするのではなく、**DynamoDB のアクセスパターンとしてタグ検索を設計する**方針を取る。

## アーキテクチャ

```
クライアント / 管理UI / curl
  ↓ HTTP リクエスト
API Gateway (REST API)
  ↓ プロキシ統合
Lambda関数 (Python)
  ↓ Prompt CRUD / バリデーション
DynamoDB テーブル
```

## 技術スタック

- **API Gateway (REST API)**: AIプロンプト管理用エンドポイントの公開
- **Lambda (Python 3.12)**: プロンプトCRUD、入力バリデーション、レスポンス整形
- **DynamoDB**: プロンプト定義の永続化
- **IAM**: Lambda → DynamoDB へのアクセス制御
- **CloudWatch Logs**: Lambda 関数のログ出力

## 作成物

- `/prompts` エンドポイントに対して CRUD 操作ができる REST API
  - `GET /prompts` : プロンプト一覧取得（`?tag=summary` のようなタグ絞り込み対応）
  - `GET /prompts/{id}` : プロンプト個別取得
  - `POST /prompts` : プロンプト作成
  - `PUT /prompts/{id}` : プロンプト更新
  - `DELETE /prompts/{id}` : プロンプト削除

## 扱うデータモデル

主となるレコードは「AIに渡すプロンプト定義」を表す。

### Prompt本体アイテム

想定フィールド:

- `id`: プロンプトID（UUID想定）
- `name`: プロンプト名
- `description`: 用途説明
- `prompt_text`: 実際に AI へ渡す本文
- `variables`: テンプレート変数一覧（例: `user_name`, `topic`）
- `tags`: 分類タグ（例: `summary`, `translation`, `support`）
- `target_model`: 想定モデル名（例: `gpt-4.1`, `claude-3-7-sonnet`）
- `version`: プロンプトの版管理用番号または文字列
- `is_active`: 有効/無効フラグ
- `created_at`: 作成日時
- `updated_at`: 更新日時

内部管理用属性:

- `gsi1pk`: 一覧取得用 GSI のパーティションキー（固定値 `PROMPT` を想定）
- `gsi1sk`: 一覧取得用 GSI のソートキー（例: `2026-05-09T10:00:00Z#<id>`）

### タグ検索用インデックスアイテム

`tags` は配列であり、そのまま 1 つの GSI キーとして扱うのではなく、
**タグごとに 1 アイテムずつ索引用レコードを追加する**方針とする。

想定フィールド:

- `id`: タグ索引アイテムID（例: `PROMPT_TAG#summary#<prompt_id>`）
- `entity_type`: レコード種別（例: `PROMPT_TAG`）
- `prompt_id`: 対応するプロンプトID
- `tag`: タグ文字列（例: `summary`）
- `created_at`: ソート・一覧表示用に複製する作成日時
- `updated_at`: 必要に応じて複製する更新日時
- `name`: 一覧表示に必要なら複製するプロンプト名
- `description`: 一覧表示に必要なら複製する説明
- `target_model`: 一覧表示に必要なら複製する対象モデル
- `is_active`: 一覧表示に必要なら複製する有効フラグ
- `gsi2pk`: タグ検索用 GSI のパーティションキー（例: `TAG#summary`）
- `gsi2sk`: タグ検索用 GSI のソートキー（例: `2026-05-09T10:00:00Z#<prompt_id>`）

最初はシンプルな CRUD に集中し、履歴管理やレビュー承認フローはスコープ外とする。

## エンドポイント設計

### `GET /prompts`

- `tag` クエリパラメータが未指定なら全プロンプト一覧を返す
- `tag` クエリパラメータが指定されていれば、そのタグを持つプロンプト一覧を返す
- いずれも DynamoDB `Query` ベースで取得し、Lambda 側での全件走査 + フィルタは行わない
- 返却項目は管理しやすいように JSON 配列形式とし、**一覧では `id`, `name`, `description`, `tags`, `target_model`, `is_active`, `created_at`, `updated_at` などのサマリ項目を返す**
- サイズが大きくなりやすい `prompt_text` は一覧では返さず、**詳細は `GET /prompts/{id}` で取得する**
- ページング対応のため、`limit` と `next_token` を受け取れるようにする

ページング方針:

- `tag` 未指定時は一覧取得用 GSI (`gsi1`) に対して `Query` + `Limit` + `ExclusiveStartKey` を使う
- `tag` 指定時はタグ検索用 GSI (`gsi2`) に対して `Query` + `Limit` + `ExclusiveStartKey` を使う
- レスポンスには `items` と `next_token` を含め、`next_token` が存在する間だけ次ページを取得可能にする
- `next_token` は DynamoDB の `LastEvaluatedKey` をそのまま返すのではなく、JSON化して Base64 エンコードした文字列として扱う
- これにより API 利用者は offset ベースではなく cursor ベースでページを進める
- 並び順は `gsi1sk` または `gsi2sk` により時系列で制御し、必要に応じて新しい順で返せるように `ScanIndexForward = false` を利用する

レスポンス例:

```json
{
  "items": [
    {
      "id": "xxxx",
      "name": "summary-assistant"
    }
  ],
  "count": 1,
  "next_token": "eyJpZCI6ICJ4eHh4In0="
}
```

注意:

- この構成では `GET /prompts/{id}` は高速に `GetItem` できる
- `GET /prompts` は主テーブルではなく GSI を `Query` するため、`Scan` より効率よく一覧取得できる
- `GET /prompts` で使う `gsi1pk = "PROMPT"` は API 利用者から受け取る値ではなく、Lambda 内部で固定値として指定する
- `GET /prompts?tag=summary` でも `FilterExpression` ではなくタグ検索用 GSI を使うことで、タグ絞り込みをアクセスパターンとして表現できる
- DynamoDB はRDBのような自由検索ではないため、「どの一覧をどう並べて取りたいか」を先にキー設計へ落とし込む必要がある
- 今回は「全件一覧を時系列でページング取得する」「タグごとに一覧を時系列でページング取得する」という 2 つのアクセスパターンを GSI に明示的に持たせる

### `GET /prompts/{id}`

- 指定IDのプロンプトを1件返す
- `prompt_text` を含む完全なプロンプト定義はこのエンドポイントで返す
- 存在しない場合は `404 Not Found`

### `POST /prompts`

- 新規プロンプトを作成する
- 最低限 `name`, `prompt_text` を必須とする
- `id`, `created_at`, `updated_at` は Lambda 側で補完可能にする
- Prompt本体アイテムに加えて、`tags` の各要素に対応するタグ検索用インデックスアイテムも作成する

### `PUT /prompts/{id}`

- 既存プロンプトを更新する
- `name`, `description`, `prompt_text`, `variables`, `tags`, `target_model`, `version`, `is_active` を更新対象とする
- 更新時は `updated_at` を自動更新する
- `tags` が変更された場合は、古いタグ索引アイテムを削除し、新しいタグ索引アイテムを再作成して整合性を保つ

### `DELETE /prompts/{id}`

- 指定IDのプロンプトを削除する
- Prompt本体アイテムに加えて、関連するタグ索引アイテムも削除する
- 削除対象が存在しない場合の扱いは、実装時に `404` または冪等性重視の `204` を選べるように整理する

## 構成ファイル（予定）

```
dynamo_lambda/
├── PLAN.md                 # 本ファイル（実装プラン）
├── README.md               # プロジェクト説明・API利用例
├── provider.tf             # AWSプロバイダ設定
├── variables.tf            # 変数定義
├── dynamodb.tf             # DynamoDBテーブル定義
├── lambda.tf               # Lambda関数定義
├── api_gateway.tf          # API Gateway定義
├── iam.tf                  # IAMロール・ポリシー定義
├── outputs.tf              # 出力定義（APIエンドポイントURL等）
├── dev.tfvars              # 開発環境用変数
├── prod.tfvars             # 本番環境用変数
└── src/
    └── lambda_function.py # Lambda関数コード（Prompt CRUD処理）
```

## 実装ステップ

### Step 1: 基盤構築

- `provider.tf` : AWSプロバイダ設定（ap-northeast-1、default_tags）
- `variables.tf` : プロジェクト名、環境、リージョン等の変数定義
- `dev.tfvars` / `prod.tfvars` : 環境ごとの値

### Step 2: DynamoDB テーブル

- `dynamodb.tf` で以下を定義:
  - テーブル名: `${project_name}-prompts-${environment}`
  - パーティションキー: `id` (String)
  - 一覧取得用 GSI: `gsi1pk` (String) + `gsi1sk` (String)
  - タグ検索用 GSI: `gsi2pk` (String) + `gsi2sk` (String)
  - 課金モード: `PAY_PER_REQUEST`
  - TTL設定: 不要

補足:

- `id` パーティションキーは「ID指定の単体取得」に使い、一覧取得は GSI に分離する
- `gsi1pk` には全件共通の固定値 `PROMPT` を入れ、`gsi1sk` に `created_at#id` を保存して時系列一覧を実現する
- `gsi1` には一覧表示に必要なサマリ属性のみを投影し、サイズの大きい `prompt_text` は含めない
- タグ検索は `tags` 配列そのものをキーにせず、タグごとの索引アイテムに `gsi2pk = TAG#<tag>` を持たせて実現する
- これにより、`GET /prompts?tag=summary` でも `Query` ベースでページングでき、`FilterExpression` による後段フィルタを避けられる
- これにより `GET /prompts` は `Query` ベースでページングでき、全件走査ベースの `Scan` を避けられる
- `Prompt` 本体と `PROMPT_TAG` 索引アイテムを同一テーブルに保存し、アクセスパターンごとに GSI を使い分ける
- 将来的に active のみの一覧や target_model ごとの一覧が必要になれば、別 GSI または別索引アイテムを追加検討する

一覧取得の実装イメージ:

- 主テーブル: `id = <uuid>`
- GSI: `gsi1pk = "PROMPT"`, `gsi1sk = "2026-05-09T10:00:00Z#<id>"`
- `Query(IndexName="gsi1", KeyConditionExpression="gsi1pk = :pk")` のように、Lambda 内部で `:pk = "PROMPT"` を固定指定して一覧取得する
- タグ索引アイテム: `id = "PROMPT_TAG#summary#<id>"`, `gsi2pk = "TAG#summary"`, `gsi2sk = "2026-05-09T10:00:00Z#<id>"`
- `Query(IndexName="gsi2", KeyConditionExpression="gsi2pk = :pk")` のようにタグ別一覧取得する
- 実運用で「active のみ取得」など別軸の一覧が増える場合は、アクセスパターンごとに GSI または索引アイテムを追加する

### Step 3: Lambda関数

- `src/lambda_function.py` : Prompt CRUD ハンドラを実装
  - API Gateway プロキシ統合に対応したリクエスト/レスポンス形式
  - `httpMethod` と `resource` または `pathParameters` でルーティング
  - boto3 で DynamoDB を操作
  - `POST /prompts` では Prompt本体アイテムの `gsi1pk`, `gsi1sk` を保存し、あわせてタグ索引アイテム (`gsi2pk`, `gsi2sk`) も作成する
  - `GET /prompts` では `limit`, `next_token`, `tag` を受け取り、`tag` 未指定時は Lambda 内部で `gsi1pk = "PROMPT"` を固定指定して `gsi1` を `Query` し、`tag` 指定時は `gsi2pk = "TAG#<tag>"` で `gsi2` を `Query` する
  - `LastEvaluatedKey` があれば `next_token` に変換して返す
  - 一覧APIではサマリ属性のみを返し、`prompt_text` は個別取得APIで返す
  - `PUT /prompts/{id}` では Prompt本体アイテムを更新し、タグ変更があればタグ索引アイテムも同期する
  - `DELETE /prompts/{id}` では Prompt本体アイテムとタグ索引アイテムを削除する
  - 複数アイテムの整合性を高めたい場合は `TransactWriteItems` の利用も検討する
  - JSON ボディのパースと必須項目チェック
  - エラーハンドリング（400、404、500）
  - CORS を考慮したレスポンスヘッダの返却

- `lambda.tf` : Lambda関数リソース定義
  - `archive_file` でソースコードを ZIP 化
  - 環境変数に DynamoDB テーブル名を渡す

### Step 4: IAM

- `iam.tf` で以下を定義:
  - Lambda実行ロール（AssumeRole: `lambda.amazonaws.com`）
  - `AWSLambdaBasicExecutionRole`（CloudWatch Logs用）
  - DynamoDB操作用カスタムポリシー（`GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`）
  - 対象リソースはテーブル ARN と GSI ARN に限定（最小権限の原則）

### Step 5: API Gateway

- `api_gateway.tf` で以下を定義:
  - REST API の作成
  - `/prompts` リソースと `/{id}` 子リソース
  - 各HTTPメソッド（GET, POST, PUT, DELETE）の定義
  - Lambda プロキシ統合（`AWS_PROXY`）
  - デプロイメントとステージ（`dev` / `prod`）
  - Lambda の invoke 権限（`aws_lambda_permission`）

必要に応じて:

- `OPTIONS` メソッドを追加して CORS 対応を明示する
- ブラウザやフロントエンドから利用するなら `Access-Control-Allow-Origin` などの設計も合わせて行う

### Step 6: 出力とテスト

- `outputs.tf` : APIエンドポイントURL、DynamoDBテーブル名、Lambda関数名を出力
- `README.md` に `curl` でのプロンプト CRUD テスト例とタグ絞り込み取得例を記載

テスト例のイメージ:

```bash
curl -X POST "$API_URL/prompts" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "summary-assistant",
    "description": "長文を要約するためのプロンプト",
    "prompt_text": "以下の文章を3行で要約してください: {{input_text}}",
    "variables": ["input_text"],
    "tags": ["summary"],
    "target_model": "gpt-4.1",
    "version": "v1",
    "is_active": true
  }'

curl "$API_URL/prompts?tag=summary"
```

## 学習ポイント

1. **API Gateway + Lambda統合**: プロキシ統合によるリクエスト/レスポンスのマッピング
2. **DynamoDB の基本操作**: prompt エンティティに対する CRUD 操作（boto3）
3. **ドメインを意識した API 設計**: `/items` ではなく `/prompts` として意味のあるリソース名にする
4. **IAM最小権限**: 必要な操作・リソースのみに限定したポリシー設計
5. **サーバーレスパターン**: API Gateway → Lambda → DynamoDB の王道構成
6. **アクセスパターン駆動の設計**: `FilterExpression` に頼らず、全件一覧とタグ一覧を別インデックスで表現する考え方

## 注意事項

- API Gateway のデプロイには明示的な `aws_api_gateway_deployment` が必要（リソース変更時の再デプロイに注意）
- DynamoDB の `PAY_PER_REQUEST` はリクエスト量が少ない開発環境向け（本番は `PROVISIONED` も検討）
- Lambda関数のコールドスタートに注意（Python は比較的軽量）
- GSI は一覧取得を効率化できる一方、書き込み時には GSI 分の更新コストと整合性を考慮する
- `FilterExpression` を後から足しても読み取り量は減らないため、必要な一覧・検索条件はキー設計または GSI で解決する前提で考える
- `created_at` を `gsi1sk` に使う場合、同時刻衝突を避けるため `created_at#id` のように一意性を持たせると安全
- `tags` は複数値属性なので、そのまま単純に 1 つの GSI キーへ載せるのではなく、タグごとの索引アイテムを持つ設計にした方が扱いやすい
- タグ索引アイテムに一覧用属性を複製する場合は、更新漏れを防ぐために書き込み処理の責務を明確にする
- もし `GET /prompts` で毎回 `prompt_text` を含む完全データを返したい要件なら、`gsi1` のメリットは薄くなるため、主テーブル `Scan` に寄せる簡易設計も選択肢になる
- API Gateway のステージ変数や高度なスロットリング設定は今回はスコープ外とする
- Prompt 本文には機密情報を直接埋め込まない方針とし、シークレットや固定資格情報は別管理にする
