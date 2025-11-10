# S3 Website Module

## 概要
S3バケットを使った静的ウェブサイトホスティングを管理するTerraformモジュール。

## 機能

- S3バケットの作成と管理
- バージョニング設定
- パブリックアクセス制御
- バケットポリシー（パブリックアクセスまたはCloudFront OAC）
- 静的ウェブサイトホスティング設定
- ファイルアップロード（自動MIMEタイプ判定）

## 使用例

### S3単体での静的ウェブサイトホスティング
```hcl
module "s3_website" {
  source = "./modules/s3_website"

  bucket_name            = "my-static-website-bucket"
  enable_versioning      = false
  block_public_access    = false
  enable_public_access   = true
  enable_website_hosting = true
  
  website_files = {
    "index.html" = {
      key          = "index.html"
      source       = "./website/index.html"
      content_type = "text/html"
    }
  }

  tags = {
    Environment = "development"
  }
}
```

### CloudFront経由でのアクセス
```hcl
module "s3_website" {
  source = "./modules/s3_website"

  bucket_name                 = "my-static-website-bucket"
  enable_versioning           = true
  block_public_access         = true
  enable_public_access        = false
  enable_website_hosting      = false
  cloudfront_oac_arn          = "arn:aws:cloudfront::..."
  cloudfront_distribution_arn = "arn:aws:cloudfront::..."
  
  website_files = {
    "index.html" = {
      key          = "index.html"
      source       = "./website/index.html"
      content_type = "text/html"
    }
  }

  tags = {
    Environment = "production"
  }
}
```

## 入力変数

| 変数名 | 型 | デフォルト | 説明 |
|--------|-----|-----------|------|
| `bucket_name` | string | - | S3バケット名（必須） |
| `enable_versioning` | bool | false | バージョニングの有効化 |
| `block_public_access` | bool | true | パブリックアクセスのブロック |
| `enable_public_access` | bool | false | パブリックアクセスポリシーの適用 |
| `cloudfront_oac_arn` | string | "" | CloudFront OACのARN |
| `cloudfront_distribution_arn` | string | "" | CloudFront DistributionのARN |
| `enable_website_hosting` | bool | true | S3静的ウェブサイトホスティングの有効化 |
| `index_document` | string | "index.html" | インデックスドキュメント |
| `error_document` | string | "error.html" | エラードキュメント |
| `website_files` | map(object) | {} | アップロードするファイル |
| `tags` | map(string) | {} | リソースタグ |

## 出力値

| 出力名 | 説明 |
|--------|------|
| `bucket_id` | S3バケットID |
| `bucket_arn` | S3バケットARN |
| `bucket_domain_name` | S3バケットのドメイン名 |
| `bucket_regional_domain_name` | S3バケットのリージョナルドメイン名 |
| `website_endpoint` | S3静的ウェブサイトエンドポイント |
| `website_domain` | S3静的ウェブサイトドメイン |

## アーキテクチャパターン

### パターン1: S3単体（開発環境向け）
```
インターネット → S3 Bucket (Public)
```
- `block_public_access = false`
- `enable_public_access = true`
- `enable_website_hosting = true`

### パターン2: CloudFront経由（本番環境向け）
```
インターネット → CloudFront → S3 Bucket (Private)
```
- `block_public_access = true`
- `enable_public_access = false`
- `enable_website_hosting = false`
- CloudFront OACのARNを設定

## 注意事項

- バケット名はグローバルで一意である必要があります
- CloudFront使用時は `enable_website_hosting = false` を推奨
- S3単体使用時はHTTPのみサポート（HTTPSはCloudFrontで実装）
