terraform {
  required_version = ">= 1.10.0"

  # リモートステートは S3 バックエンドを使用します。
  # 実際の bucket / key / region / dynamodb_table などは
  # backend/dev.hcl や backend/prod.hcl のような外部設定から読み込みます。
  backend "s3" {}
}
