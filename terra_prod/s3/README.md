# S3 Static Website Hosting

## 概要
S3を使った静的サイト配信用のTerraform構成です。Phase 1 のリファクタにより、命名規則・タグ・環境差分・バケットポリシー・backend方針を整理し、開発環境と本番環境の責務を明確に分離しました。

### 技術スタック
- AWS S3（静的ウェブサイトホスティング）
- Terraform（IaC）
- AWS Provider v6.0

### 作成物
シンプルな静的サイト用バケットとアクセスログ用バケットを作成します。`development` では S3 Website Hosting を有効にして素早く確認できる構成、`staging` / `production` では private origin 前提の構成として Website endpoint を作らない構成です。

## 構成ファイル
- **`provider.tf`**: AWSプロバイダーの設定
- **`backend.tf`**: S3リモートバックエンドの有効化（実値は外部backend設定ファイルから読み込み）
- **`variables.tf`**: リージョン・環境・プロジェクト名・追加タグの定義
- **`locals.tf`**: 命名規則、環境差分マップ、共通タグ、MIMEタイプの定義
- **`s3_bucket.tf`**: S3バケット本体とバージョニング設定
- **`s3_policy.tf`**: パブリックアクセス設定とバケットポリシー
- **`s3_website.tf`**: 静的ウェブサイトホスティング設定
- **`s3_logging.tf`**: アクセスログ用バケット、S3アクセスログ、ログライフサイクル設定
- **`s3_objects.tf`**: HTMLファイルのアップロード設定
- **`outputs.tf`**: ウェブサイトのURLとバケット名の出力
- **`dev.tfvars` / `prod.tfvars`**: 環境別の設定値
- **`backend/dev.hcl.example` / `backend/prod.hcl.example`**: 環境別のbackend設定サンプル
- **`backend_bootstrap/`**: Terraform state保存用S3バケットとlock用DynamoDBテーブルを作成する初期化構成
- **`Makefile`**: backend bootstrap、本体初期化、plan/apply を簡単に実行するためのショートカット集

## コードの特徴
- **命名規則の統一**: バケット名は `project-environment-account-region-role` をベースに `locals` で一元生成し、`environment` を必ず含めます
- **環境差分の集約**: `locals.env_config` に `delivery_mode` / `website_enabled` / `public_read_enabled` / `versioning_status` をまとめ、環境差分を1箇所で追えるようにしました
- **配信責務の分離**: `development` は `s3_public`、`staging` / `production` は `cloudfront_private` 前提として、prod 系では S3 Website endpoint を作成しません
- **タグの一元化**: `provider` の `default_tags` に共通タグを集約し、リソース個別のタグは役割差分だけを持たせています
- **ポリシー記述の統一**: バケットポリシーは `aws_iam_policy_document` ベースに統一し、`jsonencode` の直書きを解消しました
- **自動MIMEタイプ判定**: `locals`ブロックでファイル拡張子とMIMEタイプのマッピングを定義し、`lookup`関数で適切なContent-Typeを自動設定
- **ファイル変更検知**: `etag`属性にMD5ハッシュを使用し、ファイル内容の変更を検知して自動再アップロード
- **バリデーション機能**: 変数定義で許可されたリージョンと環境名のみを受け入れるバリデーションルールを実装
- **リモートステート対応**: S3 backend + lock設定により、複数人で安全にTerraform stateを共有できる構成を追加
- **アクセスログ管理**: ログ専用S3バケットを分離し、S3サーバーアクセスログとライフサイクルルールを設定

## 環境ごとの構成差

| Environment | Delivery Mode | Website Endpoint | Public Read | Versioning |
| --- | --- | --- | --- | --- |
| `development` | `s3_public` | 有効 | 有効 | `Suspended` |
| `staging` | `cloudfront_private` | 無効 | 無効 | `Enabled` |
| `production` | `cloudfront_private` | 無効 | 無効 | `Enabled` |

## リモートステート設定

### 目的
- `terraform.tfstate` をローカルではなく S3 に保存
- state ファイルをサーバーサイド暗号化
- lock により複数人の同時実行を防止
- 開発環境と本番環境で state ファイルの保存先キーを分離

### 構成方針
Terraform の backend は `terraform init` 前に参照されるため、state保存用のS3バケットやDynamoDBテーブルを同じ構成の中で直接自己生成することはできません。

そのため、このプロジェクトでは以下の2段構成にしています。

1. **`backend_bootstrap/`**
	- state保存用S3バケットを作成
	- バケットバージョニングを有効化
	- バケットのデフォルト暗号化（SSE-S3）を有効化
	- パブリックアクセスを完全にブロック
	- lock用DynamoDBテーブルを作成

2. **プロジェクト本体 (`terra_prod/s3/`)**
	- `backend.tf` で `backend "s3"` を有効化
	- 実際の `bucket` / `key` / `region` / `dynamodb_table` は `backend/*.hcl` から注入

### lock 方針
- `use_lockfile = true` を主軸とします
- `dynamodb_table` は既存運用との互換性が必要な場合のみ追加します
- `backend_bootstrap` の output と `backend/*.hcl.example` もこの方針に合わせて更新しています

### セットアップ手順

#### Makefile を使う場合（推奨）
初回セットアップは以下の順で進めるとスムーズです。

1. `make bootstrap-apply`
2. `make bootstrap-output`
3. `make backend-dev` または `make backend-prod`
4. 生成された `backend/dev.hcl` または `backend/prod.hcl` を編集
5. `make init ENV=dev` または `make init ENV=prod`
6. `make plan ENV=dev` または `make plan ENV=prod`
7. `make apply ENV=dev` または `make apply ENV=prod`

利用できる主なターゲット:
- `make help`: コマンド一覧を表示
- `make fmt`: Terraformコードを再帰的に整形
- `make validate`: 本体とbackend bootstrapの両方を検証
- `make bootstrap-plan`: backend用S3/DynamoDBのplanを表示
- `make bootstrap-apply`: backend用S3/DynamoDBを作成
- `make bootstrap-output`: backend設定に必要なoutputを表示
- `make backend-dev`: `backend/dev.hcl` をサンプルから生成
- `make backend-prod`: `backend/prod.hcl` をサンプルから生成
- `make init ENV=dev|prod`: backend付きで本体Terraformを初期化
- `make plan ENV=dev|prod`: 環境別のplanを表示
- `make apply ENV=dev|prod`: 環境別のapplyを実行

#### 1. backend管理用リソースを作成
`backend_bootstrap/terraform.tfvars.example` を参考に必要なら値を調整し、`backend_bootstrap/` で Terraform を実行します。

実行後、以下の output が表示されます。
- `state_bucket_name`
- `lock_table_name`
- `development_backend_config`
- `production_backend_config`

#### 2. backend設定ファイルを作成
以下のサンプルをコピーして実ファイルを作成します。
- `backend/dev.hcl.example` → `backend/dev.hcl`
- `backend/prod.hcl.example` → `backend/prod.hcl`

作成したファイルに、bootstrap の output で表示されたバケット名・テーブル名を設定します。

#### 3. 本体構成を backend 付きで初期化
- 開発環境では `backend/dev.hcl`
- 本番環境では `backend/prod.hcl`

を指定して `terraform init -reconfigure` を実行します。

#### 4. 環境ごとの tfvars で適用
- 開発環境: `dev.tfvars`
- 本番環境: `prod.tfvars`

### 重要な補足
- `backend/*.hcl` の実ファイルは環境依存値を持つため、`.example` から作成して使う想定です
- S3 backend の `use_lockfile = true` を有効化しています
- `dynamodb_table` はコメントアウト済みのオプションとして残しており、既存運用との互換性が必要なときだけ有効化します
- ただし最新の Terraform では **DynamoDB ベースのロックは非推奨（deprecated）** です。今後は S3 lockfile ベースへ寄せていくのが推奨です

## 注意事項
- バケット名はAWS全体でグローバルに一意である必要があります
- バケット名には `project` / `environment` / `account_id` / `region` / `role` を含めるため、環境ごとに別バケットが作成されます
- S3ウェブサイトエンドポイントはHTTPのみに対応しており、HTTPSには対応していません
- `production` は CloudFront 前提の private origin モードとして扱い、S3 Website endpoint 自体を作成しません
- 本番環境でHTTPSを使用する場合は、CloudFrontとの組み合わせが必要です（次フェーズで実装予定）
- アクセスログは専用のログバケットに集約され、`30`日後に `STANDARD_IA` へ移行、`180`日後に自動削除されます（必要に応じて変数で変更可能です）
- CloudFrontログ用プレフィックスも予約していますが、実際のCloudFrontアクセスログ有効化はCloudFrontディストリビューション追加後に行います
- ファイルは`website/`ディレクトリに`index.html`と`error.html`を配置する必要があります
- backend用のS3バケットとDynamoDBテーブルは、まず `backend_bootstrap/` 側で先に作成してください

## アクセスログ管理

### 実装内容
- 静的サイト本体バケットの **S3サーバーアクセスログ** を有効化
- ログ保存用の **専用S3バケット** を追加
- ログバケットに対して **パブリックアクセスブロック** を適用
- ログを `STANDARD_IA` へ移行し、一定期間後に削除する **ライフサイクルルール** を追加
- 将来のCloudFront導入に備えて、CloudFrontログ保存用プレフィックスを予約

### 主な出力値
- `access_log_bucket_name`: ログ専用バケット名
- `s3_access_log_prefix`: S3アクセスログの保存先プレフィックス
- `cloudfront_access_log_prefix`: 将来のCloudFrontログ保存用プレフィックス
