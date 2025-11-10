# S3 + CloudFront Static Website Hosting - モジュール化構成

## 概要
S3とCloudFrontを使った静的ウェブサイトホスティングのTerraform構成。モジュール化により、S3とCloudFrontを分離し、環境に応じて柔軟に構成を切り替えることができます。

## アーキテクチャ

### 開発環境
```
Website Files → S3 Bucket (Public Access)
                ↓
            HTTP Access
```
- S3単体での静的ウェブサイトホスティング
- パブリックアクセス許可
- HTTPのみ

### 本番環境
```
Website Files → S3 Bucket (Private) → CloudFront Distribution → HTTPS Access
                                       ↑
                                    OAC (Origin Access Control)
```
- CloudFront経由でのアクセス
- S3はプライベート（OACでCloudFrontのみアクセス可能）
- HTTPSサポート
- グローバルCDN配信

## ディレクトリ構造

```
terraform/s3_cloudfront/
├── main.tf                      # メイン設定（モジュール呼び出し）
├── variables.tf             # ルートモジュールの変数定義
├── outputs.tf               # ルートモジュールの出力定義
├── provider.tf                  # プロバイダー設定
├── dev.tfvars              # 開発環境設定
├── prod.tfvars             # 本番環境設定
├── website/                     # ウェブサイトファイル
│   ├── index.html
│   └── error.html
└── modules/                     # モジュール
    ├── s3_website/             # S3ウェブサイトモジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── cloudfront/             # CloudFrontモジュール
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## モジュール詳細

### S3 Website Module (`modules/s3_website/`)

S3バケットの作成と静的ウェブサイトホスティングの設定を管理します。

**主な機能:**
- S3バケットの作成とバージョニング管理
- パブリックアクセス設定（環境に応じて制御）
- バケットポリシー（パブリックアクセスまたはCloudFront OAC）
- 静的ウェブサイトホスティング設定
- ファイルアップロード（自動MIMEタイプ判定）

**入力変数:**
- `bucket_name`: バケット名
- `enable_versioning`: バージョニング有効化フラグ
- `block_public_access`: パブリックアクセスブロックフラグ
- `enable_public_access`: パブリックアクセス許可フラグ
- `cloudfront_oac_arn`: CloudFront OAC ARN
- `cloudfront_distribution_arn`: CloudFront Distribution ARN
- `enable_website_hosting`: S3ウェブサイトホスティング有効化フラグ
- `website_files`: アップロードするファイルのマップ
- `tags`: リソースタグ

**出力:**
- `bucket_id`: バケットID
- `bucket_arn`: バケットARN
- `bucket_regional_domain_name`: リージョナルドメイン名
- `website_endpoint`: ウェブサイトエンドポイント

### CloudFront Module (`modules/cloudfront/`)

CloudFront DistributionとOAC（Origin Access Control）の設定を管理します。

**主な機能:**
- CloudFront Distribution作成
- OAC（Origin Access Control）設定
- カスタムエラーレスポンス設定
- HTTPS/TLS設定
- カスタムドメインサポート（ACM証明書）
- キャッシュポリシー設定

**入力変数:**
- `distribution_name`: Distribution名
- `s3_bucket_regional_domain_name`: S3バケットのドメイン名
- `price_class`: 価格クラス（デフォルト: PriceClass_200）
- `aliases`: カスタムドメイン名
- `acm_certificate_arn`: ACM証明書ARN
- `viewer_protocol_policy`: ビューワープロトコルポリシー
- `custom_error_responses`: カスタムエラーレスポンス設定
- `tags`: リソースタグ

**出力:**
- `distribution_id`: Distribution ID
- `distribution_arn`: Distribution ARN
- `distribution_domain_name`: ドメイン名
- `oac_id`: OAC ID

## 使用方法

### 初期化
```bash
cd terraform/s3_cloudfront
terraform init
```

### 開発環境へのデプロイ（S3のみ）
```bash
# プラン確認
terraform plan -var-file="dev.tfvars"

# 適用
terraform apply -var-file="dev.tfvars"
```

開発環境では `enable_cloudfront = false` となっており、S3単体での静的ウェブサイトホスティングが有効になります。

### 本番環境へのデプロイ（S3 + CloudFront）
```bash
# プラン確認
terraform plan -var-file="prod.tfvars"

# 適用
terraform apply -var-file="prod.tfvars"
```

本番環境では `enable_cloudfront = true` となっており、CloudFrontを経由したアクセスが有効になります。

### リソースの削除
```bash
# 開発環境
terraform destroy -var-file="dev.tfvars"

# 本番環境
terraform destroy -var-file="prod.tfvars"
```

## 環境別設定

### 開発環境 (`dev.tfvars`)
```hcl
aws_region        = "ap-northeast-1"
environment       = "development"
enable_cloudfront = false  # S3単体
```

**特徴:**
- CloudFront無効
- S3パブリックアクセス許可
- バージョニング無効
- HTTPアクセス

### 本番環境 (`prod.tfvars`)
```hcl
aws_region            = "ap-northeast-1"
environment           = "production"
enable_cloudfront     = true
cloudfront_price_class = "PriceClass_200"
```

**特徴:**
- CloudFront有効
- S3プライベート（OAC経由アクセスのみ）
- バージョニング有効
- HTTPSアクセス
- グローバルCDN配信

## カスタムドメインの設定

カスタムドメインを使用する場合は、以下の手順を実施してください：

1. **ACM証明書の作成**（us-east-1リージョン）
   ```bash
   # AWS CLIで証明書リクエスト
   aws acm request-certificate \
     --domain-name www.example.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. **prod.tfvarsの更新**
   ```hcl
   custom_domain_names = ["www.example.com"]
   acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
   ```

3. **Route 53でのDNS設定**
   - CloudFrontのドメイン名にCNAMEまたはAliasレコードを設定

## 出力情報

デプロイ後、以下の情報が出力されます：

### S3関連
- `s3_bucket_id`: S3バケットID
- `s3_bucket_arn`: S3バケットARN
- `s3_website_endpoint`: S3ウェブサイトエンドポイント（CloudFront無効時）
- `s3_website_url`: S3ウェブサイトURL（CloudFront無効時）

### CloudFront関連（有効時のみ）
- `cloudfront_distribution_id`: CloudFront Distribution ID
- `cloudfront_distribution_arn`: CloudFront Distribution ARN
- `cloudfront_domain_name`: CloudFrontドメイン名
- `cloudfront_url`: CloudFrontのHTTPS URL

### 共通
- `website_url`: アクセス用URL（CloudFront有効時はHTTPS、無効時はS3のHTTP URL）

## モジュール化のメリット

1. **関心の分離**: S3とCloudFrontの設定が明確に分離され、それぞれ独立して管理可能
2. **再利用性**: 他のプロジェクトでもモジュールを再利用可能
3. **柔軟性**: 環境に応じてCloudFrontの有効/無効を簡単に切り替え可能
4. **保守性**: 各モジュールが独立しているため、変更の影響範囲が明確
5. **テスト性**: モジュール単位でのテストが容易

## トラブルシューティング

### CloudFrontのキャッシュクリア
```bash
# Distribution IDを取得
terraform output cloudfront_distribution_id

# キャッシュ無効化
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

### S3バケットポリシーのエラー
CloudFront有効化時に、S3バケットのパブリックアクセスブロックとバケットポリシーの設定タイミングでエラーが発生する場合があります。その場合は再度 `terraform apply` を実行してください。

## 次のステップ

- [ ] Route 53統合（カスタムドメイン設定）
- [ ] ACM証明書の自動作成
- [ ] CloudFrontのログ設定
- [ ] WAF統合
- [ ] Lambda@Edge統合

## 注意事項

- CloudFront Distributionの作成には10〜15分程度かかります
- ACM証明書はus-east-1リージョンで作成する必要があります
- CloudFrontのキャッシュにより、変更が反映されるまで時間がかかる場合があります
- 本番環境でのカスタムドメイン使用には、事前にACM証明書の検証が必要です
