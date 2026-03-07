# S3 + CloudFront Static Website Hosting

## 概要
S3とCloudFrontを使った静的ウェブサイトホスティングのTerraform構成です。モジュール化により再利用性を高め、環境に応じて柔軟に構成を切り替えることができます。

### 技術スタック
- AWS S3（静的ウェブサイトホスティング）
- AWS CloudFront（CDN配信）
- OAC（Origin Access Control）
- Terraform（Infrastructure as Code）
- モジュール化構成

### 作成物
本プロジェクトは、静的ウェブサイトをホスティングするための2つの異なる構成を提供します。

**開発環境:**
S3バケット単体で静的ウェブサイトをホスティングします。パブリックアクセスが許可されており、HTTPでの直接アクセスが可能です。迅速な開発とテストに適しています。

**本番環境:**
CloudFrontを経由した安全な配信システムです。S3バケットはプライベートに設定され、CloudFrontのみがOACを介してアクセスできます。HTTPS通信により安全性が確保され、グローバルなCDNによって世界中どこからでも高速にコンテンツが配信されます。

## 構成ファイル

**メイン構成:**
- `main.tf` - モジュール呼び出しと全体の構成管理
- `provider.tf` - AWSプロバイダー設定
- `variables.tf` - 変数定義
- `outputs.tf` - 出力定義
- `dev.tfvars` / `prod.tfvars` - 環境別設定ファイル

**モジュール:**
- `modules/s3_website/` - S3バケットと静的ウェブサイトホスティング設定
- `modules/cloudfront/` - CloudFront DistributionとOAC設定

**ウェブサイトファイル:**
- `website/` - デプロイされる静的HTMLファイル（index.html、error.html）

## コードの特徴

### モジュール化による設計
S3とCloudFrontを独立したモジュールとして分離し、環境に応じて柔軟に組み合わせることができます。開発環境ではS3のみ、本番環境ではCloudFrontを追加するなど、`enable_cloudfront`フラグ一つで切り替えが可能です。

### OAC（Origin Access Control）の実装
従来のOAI（Origin Access Identity）ではなく、より新しく推奨されるOACを使用しています。これにより、S3バケットをプライベートに保ちながら、CloudFrontからのみアクセスを許可するセキュアな構成を実現しています。

### 自動MIMEタイプ判定
ファイルアップロード時に拡張子から適切なContent-Typeを自動的に設定します。これにより、ブラウザが正しくファイルを解釈し、表示することができます。

### 環境別の最適化
開発環境では迅速なイテレーションを重視し、本番環境ではセキュリティと性能を重視した設定になっています。tfvarsファイルを切り替えるだけで、適切な構成がデプロイされます。

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

## 注意事項

- CloudFront Distributionの作成には10〜15分程度かかります
- カスタムドメインを使用する場合、ACM証明書は必ずus-east-1リージョンで作成してください
- CloudFrontのキャッシュにより、ウェブサイトの変更が即座に反映されない場合があります。キャッシュクリアが必要な場合は、CloudFrontのInvalidation機能を使用してください
- S3バケットポリシーの設定タイミングによっては、初回のterraform applyがエラーになる場合があります。その場合は再度実行してください
