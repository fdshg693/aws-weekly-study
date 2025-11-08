# S3静的ウェブサイトホスティング - Terraform学習用スニペット

このディレクトリには、S3を使用した静的ウェブサイトホスティングをTerraformで実装するための学習用スニペットが含まれています。

## 📚 ファイル構成

| ファイル | 学習内容 | 主要概念 |
|---------|---------|---------|
| `provider.tf` | プロバイダー設定 | マルチリージョン、バックエンド、認証 |
| `variables.tf` | 変数定義 | 型定義、バリデーション、デフォルト値 |
| `outputs.tf` | 出力定義 | 出力値、機密情報、コマンド生成 |
| `01_basic_bucket.tf` | 基本バケット設定 | S3バケット、ウェブサイトホスティング、パブリックアクセス |
| `02_bucket_with_objects.tf` | オブジェクト管理 | ファイルアップロード、MIME type、for_each |
| `03_cloudfront_distribution.tf` | CloudFront統合 | CDN、OAI、キャッシング、カスタムエラー |
| `04_route53_acm.tf` | DNS & SSL/TLS | Route53、ACM証明書、DNS検証、条件付きリソース |
| `05_redirect_bucket.tf` | リダイレクト設定 | リダイレクトバケット、ルーティングルール |
| `06_lifecycle_logging.tf` | ライフサイクル & ログ | ライフサイクルポリシー、アクセスログ、暗号化 |
| `07_cache_invalidation.tf` | キャッシュ無効化 | null_resource、local-exec、トリガー |

## 🎯 学習の進め方

### ステップ1: 基本構成の理解
```bash
# プロバイダーと変数の確認
cat provider.tf variables.tf

# 基本バケット設定の理解
cat 01_basic_bucket.tf
```

### ステップ2: 基本構成のデプロイ
```bash
# 初期化
terraform init

# プラン確認（ドライラン）
terraform plan

# 基本バケットのみデプロイ（CloudFrontなし）
# 他のファイルを一時的にリネームまたは削除
terraform apply -target=aws_s3_bucket.static_website \
                -target=aws_s3_bucket_versioning.static_website \
                -target=aws_s3_bucket_website_configuration.static_website
```

### ステップ3: CloudFront統合
```bash
# CloudFrontディストリビューション追加
terraform plan
terraform apply
```

### ステップ4: カスタムドメイン設定（オプション）
```bash
# ドメインを所有している場合
terraform apply \
  -var='use_custom_domain=true' \
  -var='domain_name=example.com'
```

### ステップ5: キャッシュ無効化テスト
```bash
# ファイル更新後、キャッシュ無効化
terraform apply -var='cache_invalidation_trigger=v2'
```

## 📖 主要概念の学習ポイント

### 1. リソース分離パターン
Terraform AWS Provider v4以降では、S3関連設定が個別リソースに分離されています：
- `aws_s3_bucket`: バケット本体
- `aws_s3_bucket_versioning`: バージョニング設定
- `aws_s3_bucket_website_configuration`: ウェブサイト設定
- `aws_s3_bucket_public_access_block`: パブリックアクセス制御

### 2. データソースの活用
既存リソース参照や外部情報取得：
```hcl
data "aws_caller_identity" "current" {}
data "aws_route53_zone" "main" { ... }
data "aws_cloudfront_cache_policy" "caching_optimized" { ... }
```

### 3. 条件付きリソース作成
`count` や `for_each` を使用：
```hcl
resource "aws_acm_certificate" "cert" {
  count = var.use_custom_domain ? 1 : 0
  ...
}
```

### 4. 依存関係管理
明示的な依存関係：
```hcl
depends_on = [aws_s3_bucket_public_access_block.static_website]
```

### 5. ライフサイクル制御
```hcl
lifecycle {
  create_before_destroy = true
  prevent_destroy = true
  ignore_changes = [tags]
}
```

## 🔧 実践的な使用例

### 完全なデプロイ（カスタムドメインなし）
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### カスタムドメイン付きデプロイ
```bash
terraform apply \
  -var='use_custom_domain=true' \
  -var='domain_name=example.com' \
  -var='environment=prod'
```

### 変数ファイルを使用
```bash
# dev.tfvars を作成
cat > dev.tfvars <<EOF
aws_region = "ap-northeast-1"
environment = "dev"
enable_logging = false
cloudfront_price_class = "PriceClass_100"
EOF

# 適用
terraform apply -var-file=dev.tfvars
```

### 特定リソースのみ更新
```bash
# CloudFrontのみ再作成
terraform apply -target=aws_cloudfront_distribution.static_website
```

### 状態確認
```bash
# リソース一覧
terraform state list

# 特定リソースの詳細
terraform state show aws_s3_bucket.static_website

# 出力値確認
terraform output
terraform output -json
```

## 🚀 デプロイ後の操作

### ファイルアップロード
```bash
# S3バケット名取得
BUCKET_NAME=$(terraform output -raw bucket_name)

# ファイルアップロード
aws s3 cp index.html s3://$BUCKET_NAME/ --content-type text/html

# ディレクトリ同期
aws s3 sync ./website s3://$BUCKET_NAME/ --delete
```

### CloudFrontキャッシュ無効化
```bash
# ディストリビューションID取得
DIST_ID=$(terraform output -raw cloudfront_distribution_id)

# 全キャッシュ無効化
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"

# 特定ファイルのみ
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/index.html" "/style.css"
```

### アクセスログ確認
```bash
# ログバケット名取得
LOGS_BUCKET=$(terraform output -raw logs_bucket_id)

# ログ一覧
aws s3 ls s3://$LOGS_BUCKET/access-logs/

# ログダウンロード
aws s3 sync s3://$LOGS_BUCKET/access-logs/ ./logs/
```

## ⚠️ 注意事項

### コスト管理
- CloudFrontは無料枠があるが、データ転送量に応じて課金
- ログ保存にはストレージコストが発生
- Route53ホストゾーンは月額$0.50

### セキュリティ
- 本番環境ではCloudFront + OAIを使用し、S3への直接アクセスを防ぐ
- パブリックアクセスは最小限に
- HTTPS必須（ACM証明書使用）

### 状態管理
- `terraform.tfstate` は機密情報を含むため厳重管理
- チーム開発ではS3バックエンド + DynamoDBロック推奨
- `.gitignore` に必ず追加

### リソース削除
```bash
# 全リソース削除前にバケットを空に
BUCKET_NAME=$(terraform output -raw bucket_name)
aws s3 rm s3://$BUCKET_NAME --recursive

# 削除実行
terraform destroy
```

## 🔗 関連リソース

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Developer Guide](https://docs.aws.amazon.com/ja_jp/AmazonCloudFront/latest/DeveloperGuide/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 📝 学習チェックリスト

- [ ] Terraformの基本構文理解（resource, data, variable, output）
- [ ] S3バケットの作成と設定
- [ ] 静的ウェブサイトホスティングの有効化
- [ ] パブリックアクセス制御とバケットポリシー
- [ ] CloudFrontディストリビューションの構築
- [ ] Origin Access Identity (OAI) の理解
- [ ] キャッシュポリシーとビヘイビア設定
- [ ] Route53とACMの統合
- [ ] DNS検証によるSSL証明書発行
- [ ] ライフサイクルポリシーの設定
- [ ] アクセスログとモニタリング
- [ ] キャッシュ無効化の実行
- [ ] 条件付きリソース作成（count, for_each）
- [ ] 変数とバリデーション
- [ ] 状態管理とバックエンド設定

## 🎓 発展課題

1. **モジュール化**: 共通コンポーネントをモジュールとして切り出し
2. **CI/CD統合**: GitHub ActionsでTerraformを自動実行
3. **マルチ環境対応**: dev/staging/prod環境の分離
4. **WAF統合**: CloudFrontにWAFを追加してセキュリティ強化
5. **Lambda@Edge**: エッジでの動的処理追加
6. **Monitoringダッシュボード**: CloudWatchでメトリクス可視化

Happy Learning! 🚀
