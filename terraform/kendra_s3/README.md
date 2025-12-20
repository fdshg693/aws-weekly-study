# Amazon Kendra (Index + Web Crawler Data Source) - Terraform

## 概要
このディレクトリは、Amazon Kendra の **Index** と **WEBCRAWLER Data Source** を Terraform で作成します。
- Seed URL は `seed_urls` 変数で指定
- URL の包含/除外は `url_inclusion_patterns` / `url_exclusion_patterns`（正規表現）で指定
- 取り込む言語は `data_source_language_code` で指定（例: `ja`, `en`）

## ファイル構成
- `provider.tf`: AWS Provider 設定
- `variables.tf`: 変数定義
- `iam.tf`: Kendra 用 IAM ロール/ポリシー
- `main.tf`: `aws_kendra_index` / `aws_kendra_data_source`
- `outputs.tf`: Index/Data Source のID等
- `dev.tfvars` / `prod.tfvars`: 環境別の設定例

## 前提
- Terraform `>= 1.0`
- AWS 認証情報（例: `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` 等）
- Kendra はリージョン依存のため `aws_region` を合わせてください

## 使い方

### 1) 初期化
```bash
terraform init
```

### 2) Plan / Apply
開発環境:
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

本番環境:
```bash
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

### 3) 同期（Sync）の手動トリガー
作成した Data Source の同期を今すぐ実行したい場合は AWS CLI で開始できます。

```bash
aws kendra start-data-source-sync-job \
  --index-id "$(terraform output -raw kendra_index_id)" \
  --id "$(terraform output -raw kendra_data_source_id)"
```

同期状態の確認:
```bash
aws kendra list-data-source-sync-jobs \
  --index-id "$(terraform output -raw kendra_index_id)" \
  --id "$(terraform output -raw kendra_data_source_id)"
```

### 4) 削除
```bash
terraform destroy -var-file="dev.tfvars"
```

## メモ
- `schedule` 変数に `cron(...)` を設定すると定期同期が有効になります。未設定（`null`）の場合はスケジュール同期は無効です。
- Web Crawler の包含/除外パターンは URL に対する正規表現です。Terraform 文字列なので `\\.` のようにエスケープが必要な場合があります。
- `data_source_language_code` は Data Source が取り込むドキュメントの想定言語です。対象サイトの言語に合わせると検索精度に寄与することがあります。

## よくあるエラー

### `describeLogGroup` / `DescribeLogGroups` 権限不足
手動同期で以下のようなエラーが出る場合があります。

> Amazon Kendra can't execute the describeLogGroup action with the specified index role...

これは **Kendra Index の `role_arn`（= Index role）** に CloudWatch Logs の参照権限が不足していることが原因です。

- 対処: Index role に `logs:DescribeLogGroups`（必要に応じて `logs:DescribeLogStreams`）を付与します。
  - 本ディレクトリでは [iam.tf](iam.tf) の `kendra_logs` ポリシーで付与しています。

Index role の確認例:
```bash
aws kendra describe-index --id "$(terraform output -raw kendra_index_id)" \
  --query 'RoleArn' --output text
```
