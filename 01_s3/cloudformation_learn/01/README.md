# S3 静的ウェブサイトホスティング CloudFormation スニペット集

このディレクトリでは、S3を使用した静的ウェブサイトホスティングの構築に必要なCloudFormationテンプレートを、段階的に分けて提供しています。

## ファイル構成

### 基本バージョン
- **01_basic_bucket.yaml** - シンプルな単一ページサイト用
  - パブリックアクセス可能なS3バケット
  - 静的ウェブサイトホスティング有効化
  - インデックスドキュメント設定

### 中級バージョン
- **02_intermediate_error_page.yaml** - 複数ページ + エラーハンドリング
  - カスタムエラーページ（404.html）設定
  - ライフサイクルポリシー（古いバージョン自動削除）
  - ディレクトリ構造対応

### 発展バージョン
- **03_advanced_cloudfront.yaml** - CloudFront CDN統合
  - Origin Access Identity（OAI）でセキュア化
  - キャッシング戦略設定
  - グローバル配信

- **04_route53_dns.yaml** - カスタムドメイン接続
  - Route53 DNSレコード設定
  - CloudFrontへのエイリアス設定
  - IPv4/IPv6対応

- **05_acm_certificate.yaml** - SSL/TLS証明書
  - AWS Certificate Manager（ACM）
  - HTTPS対応
  - 自動更新

- **06_redirect_bucket.yaml** - URL統一
  - www付きドメインのリダイレクト
  - ドメイン統一

- **07_cache_invalidation.yaml** - キャッシュ管理
  - CloudFrontキャッシュ無効化
  - 自動更新スクリプト

## 使用方法

### 1. 基本セットアップ
```bash
aws cloudformation create-stack \
  --stack-name static-website \
  --template-body file://01_basic_bucket.yaml \
  --region us-east-1
```

### 2. 中級セットアップ
```bash
aws cloudformation create-stack \
  --stack-name static-website-intermediate \
  --template-body file://02_intermediate_error_page.yaml \
  --region us-east-1
```

### 3. 発展セットアップ（複合使用）
複数テンプレートを組み合わせて使用：
```bash
# CloudFront配置
aws cloudformation create-stack \
  --stack-name static-website-cdn \
  --template-body file://03_advanced_cloudfront.yaml \
  --region us-east-1

# DNS設定（Route53 Hosted Zoneが必要）
aws cloudformation create-stack \
  --stack-name static-website-dns \
  --template-body file://04_route53_dns.yaml \
  --parameters \
    ParameterKey=HostedZoneId,ParameterValue=Z1234567890ABC \
    ParameterKey=DomainName,ParameterValue=example.com \
    ParameterKey=CloudFrontDomainName,ParameterValue=d111111abcdef8.cloudfront.net \
  --region us-east-1

# SSL/TLS証明書（us-east-1リージョンで実行が必須）
aws cloudformation create-stack \
  --stack-name static-website-certificate \
  --template-body file://05_acm_certificate.yaml \
  --parameters \
    ParameterKey=DomainName,ParameterValue=example.com \
    ParameterKey=IncludeWwwDomain,ParameterValue=true \
  --region us-east-1
```

## 学習ポイント

### 各テンプレートから学べる概念

| ファイル | 主要概念 | 学習内容 |
|---------|--------|---------|
| 01_basic_bucket.yaml | S3基本 | バケット作成、パブリックアクセス、Webホスティング設定 |
| 02_intermediate_error_page.yaml | エラー処理 | エラーページ設定、ライフサイクル管理、バージョニング |
| 03_advanced_cloudfront.yaml | CDN・高度なセキュリティ | OAI、キャッシング戦略、HttpVersion設定 |
| 04_route53_dns.yaml | DNS管理 | エイリアスレコード、Route53設定 |
| 05_acm_certificate.yaml | HTTPS | ACM証明書、DNS検証 |
| 06_redirect_bucket.yaml | リダイレクト | ホストベースのリダイレクト |
| 07_cache_invalidation.yaml | 運用 | キャッシュ無効化、Lambda関数 |

## 重要な注意事項

### セキュリティ
- 基本バージョンはパブリックアクセス許可のため、プロトタイプ向け
- 本番環境ではCloudFront + OAIでアクセス制限を推奨

### リージョン指定
- ACM証明書はCloudFrontで使用する場合、**必ずus-east-1リージョンで作成**
- Route53はグローバルサービスのため、リージョン指定は不要

### ドメイン管理
- Route53を使用する場合、事前にHosted Zoneを作成必要
- Route53以外のDNSプロバイダーを使用する場合は、CNAMEレコードでCloudFrontを指定

## 実装例

### 段階的な構築フロー
1. **テスト環境** → 01_basic_bucket.yaml
2. **ステージング環境** → 01 + 02
3. **本番環境（カスタムドメイン無し）** → 01 + 02 + 03
4. **本番環境（カスタムドメイン有り）** → 全テンプレートを組み合わせ

## トラブルシューティング

### CloudFrontがS3にアクセスできない
- OAI（Origin Access Identity）が正しく設定されているか確認
- S3バケットポリシーでOAIの権限が設定されているか確認

### HTTPSで接続できない
- ACM証明書がus-east-1で作成されているか確認
- DNS検証が完了しているか確認（ACMコンソールで確認可能）

### キャッシュが更新されない
- CloudFrontキャッシュ無効化が実行されたか確認
- 無効化処理は数分かかる場合がある

## 参考リンク

- [AWS CloudFormation ドキュメント](https://docs.aws.amazon.com/cloudformation/)
- [S3 静的ウェブサイトホスティング](https://docs.aws.amazon.com/s3/latest/userguide/WebsiteHosting.html)
- [CloudFront ドキュメント](https://docs.aws.amazon.com/cloudfront/)
- [Route53 ドキュメント](https://docs.aws.amazon.com/route53/)
