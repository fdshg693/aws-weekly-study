# Amazon Kendra (Index + S3 Data Source)

## 概要
Amazon KendraのIndexとS3 Data Sourceを構築するTerraformプロジェクトです。S3バケットに保存されたドキュメントをKendraでインデックス化し、高度な検索機能を提供します。

### 技術スタック
- Amazon Kendra（エンタープライズ検索サービス）
- Amazon S3（ドキュメントストレージ）
- CloudWatch Logs（ログ記録）
- IAM（権限管理）

### 作成物
Kendraインデックスを作成し、S3バケット内のドキュメントを自動的に取り込んで検索可能にします。取り込み対象はS3バケットの指定されたプレフィックス配下（デフォルト: `documents/`）のファイルで、PDFやテキストファイルなどをアップロードすると、Kendraがコンテンツを解析してインデックス化します。定期同期をスケジュール設定することも、手動で同期をトリガーすることも可能です。

## 構成ファイル
- [provider.tf](provider.tf) - AWS Provider設定
- [variables.tf](variables.tf) - 変数定義（環境、リージョン、Kendra設定など）
- [iam.tf](iam.tf) - Kendra用IAMロールとポリシー
- [main.tf](main.tf) - KendraインデックスとData Source定義
- [s3.tf](s3.tf) - ドキュメント保存用S3バケット
- [outputs.tf](outputs.tf) - IndexとData SourceのID出力
- [dev.tfvars](dev.tfvars) / [prod.tfvars](prod.tfvars) - 環境別設定

## コードの特徴

### 言語コード設定
`data_source_language_code`変数でドキュメントの言語（ja、en等）を指定でき、Kendraの言語処理（トークナイズ、ステミングなど）を最適化します。nullの場合はKendraのデフォルト言語処理が適用されます。

### セキュアなS3バケット構成
S3バケットはPublic Accessを全面ブロックし、SSE-S3暗号化を有効化、BucketOwnerEnforcedでACLを無効化するなど、セキュリティを重視した設計になっています。

### IAMロール分離
KendraインデックスとData Sourceでそれぞれ専用のIAMロールを作成し、最小権限の原則に従って必要な権限のみを付与しています。CloudWatch Logsへのログ出力権限も含まれます。

### 柔軟な同期スケジュール
`schedule`変数でcron式を指定することで定期同期を設定でき、nullにすることで手動同期のみの運用も可能です。

## 注意事項

### 前提条件
- Terraform 1.1以上
- AWS認証情報の設定（AWS_PROFILE、AWS_ACCESS_KEY_IDなど）
- Kendraはリージョン依存のため、利用可能リージョンで`aws_region`を設定してください

### 使い方

#### ドキュメントのアップロードと同期

S3へドキュメントをアップロード(指定した言語コードに対応したファイルを推奨):
```bash
aws s3 cp ./sample.pdf "$(terraform output -raw s3_uri)"
```

手動同期の開始:
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

### よくあるエラー

**`describeLogGroup`権限不足エラー**

手動同期時に「Amazon Kendra can't execute the describeLogGroup action...」というエラーが出る場合は、Kendra IndexのIAMロールにCloudWatch Logsの参照権限が不足しています。[iam.tf](iam.tf)の`kendra_logs`ポリシーで`logs:DescribeLogGroups`と`logs:DescribeLogStreams`を付与することで解決できます。

### メモ
- デフォルトの取り込み対象プレフィックスは`documents/`ですが、変数で変更可能です
- `kendra_edition`はDEVELOPER_EDITIONとENTERPRISE_EDITIONから選択できます（開発用途ではDEVELOPER_EDITIONを推奨）
