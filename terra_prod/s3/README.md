# S3 Static Website Hosting

## 概要
S3を使った静的ウェブサイトホスティングのTerraform構成です。開発環境と本番環境で異なるセキュリティ設定を適用し、環境に応じた最適な構成を実現します。

### 技術スタック
- AWS S3（静的ウェブサイトホスティング）
- Terraform（IaC）
- AWS Provider v6.0

### 作成物
シンプルな静的ウェブサイトをS3上にホスティングします。ユーザーがウェブサイトのURLにアクセスすると、S3バケットに配置されたHTMLファイルが表示されます。エラー時には専用のエラーページが表示され、開発環境ではパブリックアクセスが可能、本番環境ではセキュリティを強化した構成となります。

## 構成ファイル
- **`provider.tf`**: AWSプロバイダーの設定
- **`backend.tf`**: S3リモートバックエンドの有効化（実値は外部backend設定ファイルから読み込み）
- **`variables.tf`**: リージョンと環境変数の定義
- **`locals.tf`**: バケット名の生成ロジックとMIMEタイプのマッピング
- **`s3_bucket.tf`**: S3バケット本体とバージョニング設定
- **`s3_policy.tf`**: パブリックアクセス設定とバケットポリシー
- **`s3_website.tf`**: 静的ウェブサイトホスティング設定
- **`s3_objects.tf`**: HTMLファイルのアップロード設定
- **`outputs.tf`**: ウェブサイトのURLとバケット名の出力
- **`dev.tfvars` / `prod.tfvars`**: 環境別の設定値
- **`backend/dev.hcl.example` / `backend/prod.hcl.example`**: 環境別のbackend設定サンプル
- **`backend_bootstrap/`**: Terraform state保存用S3バケットとlock用DynamoDBテーブルを作成する初期化構成
- **`Makefile`**: backend bootstrap、本体初期化、plan/apply を簡単に実行するためのショートカット集

## コードの特徴
- **環境別セキュリティ制御**: 開発環境ではパブリックアクセスを許可し、本番環境では完全にブロックする条件分岐を実装
- **バケット名の一意性確保**: `data.aws_caller_identity`を使用してアカウントIDとリージョンを組み合わせ、グローバルで一意なバケット名を自動生成
- **自動MIMEタイプ判定**: `locals`ブロックでファイル拡張子とMIMEタイプのマッピングを定義し、`lookup`関数で適切なContent-Typeを自動設定
- **ファイル変更検知**: `etag`属性にMD5ハッシュを使用し、ファイル内容の変更を検知して自動再アップロード
- **バリデーション機能**: 変数定義で許可されたリージョンと環境名のみを受け入れるバリデーションルールを実装
- **リモートステート対応**: S3 backend + lock設定により、複数人で安全にTerraform stateを共有できる構成を追加

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
- `dynamodb_table` も併用できる形にしており、既存運用との互換性を確保しています
- ただし最新の Terraform では **DynamoDB ベースのロックは非推奨（deprecated）** です。今後は S3 lockfile ベースへ寄せていくのが推奨です

## 注意事項
- バケット名はAWS全体でグローバルに一意である必要があります
- S3ウェブサイトエンドポイントはHTTPのみに対応しており、HTTPSには対応していません
- 本番環境でHTTPSを使用する場合は、CloudFrontとの組み合わせが推奨されます（現在は未実装）
- ファイルは`website/`ディレクトリに`index.html`と`error.html`を配置する必要があります
- backend用のS3バケットとDynamoDBテーブルは、まず `backend_bootstrap/` 側で先に作成してください
