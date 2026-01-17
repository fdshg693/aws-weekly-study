# S3 Static Website モジュール

## 概要
S3バケットを使った静的ウェブサイトホスティングを管理するモジュールです。パブリックアクセスとCloudFront OAC経由のアクセスの両方に対応しており、開発環境から本番環境まで柔軟に利用できます。

### 作成物
- **S3バケット**: 静的コンテンツを格納するストレージ
- **バージョニング設定**: ファイルの変更履歴を管理
- **パブリックアクセスブロック**: S3バケットへの直接アクセスを制御
- **バケットポリシー**: CloudFront OAC経由またはパブリックアクセスを許可
- **静的ウェブサイトホスティング設定**: index.htmlとerror.htmlの設定
- **S3オブジェクト**: ウェブサイトファイルのアップロード（自動MIMEタイプ判定）

このモジュールは2つのアーキテクチャパターンをサポートします：
1. **開発環境**: S3単体でのパブリックアクセス（`enable_public_access = true`）
2. **本番環境**: CloudFrontモジュールと組み合わせてOAC経由でのアクセス（`cloudfront_distribution_arn`を指定）

CloudFrontモジュールと組み合わせる場合、このモジュールが静的コンテンツのオリジンとなり、CloudFrontがCDNとして世界中に配信します。

## 構成ファイル
- [main.tf](main.tf): S3バケット、バージョニング、パブリックアクセスブロック、バケットポリシー、ウェブサイトホスティング設定、ファイルアップロードの定義
- [variables.tf](variables.tf): モジュールの入力変数定義。バケット名、アクセス制御、CloudFront連携、ファイルアップロード設定など
- [outputs.tf](outputs.tf): モジュールの出力値定義。バケットID/ARN、ドメイン名、ウェブサイトエンドポイントを出力

## 注意事項
- **バケット名のグローバル一意性**: S3バケット名はAWS全体で一意である必要があります。既存のバケット名と重複しないように注意してください
- **CloudFront OACとの連携**: CloudFront経由でアクセスする場合、`cloudfront_distribution_arn`を指定する必要があります。この値はCloudFront作成後に設定されるため、依存関係に注意してください
- **パブリックアクセス設定**: 本番環境では`block_public_access = true`を設定し、CloudFront経由のみでアクセスできるようにすることを推奨します
- **ファイルのMIMEタイプ**: `website_files`でファイルをアップロードする際は、正しい`content_type`を指定してください（例: text/html, text/css, application/javascript）
- **バージョニング**: 本番環境では`enable_versioning = true`を設定して、誤った削除や変更から保護することを推奨します
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
