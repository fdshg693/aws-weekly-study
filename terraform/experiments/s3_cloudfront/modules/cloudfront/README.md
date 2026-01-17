# CloudFront Module

## 概要
CloudFront DistributionとOAC（Origin Access Control）を管理するTerraformモジュール。

## 機能

- CloudFront Distribution作成
- OAC（Origin Access Control）設定
- カスタムエラーレスポンス
- HTTPS/TLS設定
- カスタムドメインサポート（ACM証明書）
- マネージドキャッシュポリシー使用
- 地理的制限
- ロギング設定

## 使用例

### 基本的な使用方法
```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  distribution_name                = "my-distribution"
  s3_bucket_regional_domain_name   = "my-bucket.s3.ap-northeast-1.amazonaws.com"
  origin_id                        = "S3-my-bucket"
  
  tags = {
    Environment = "production"
  }
}
```

### カスタムドメインとACM証明書
```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  distribution_name                = "my-distribution"
  s3_bucket_regional_domain_name   = "my-bucket.s3.ap-northeast-1.amazonaws.com"
  origin_id                        = "S3-my-bucket"
  
  aliases             = ["www.example.com", "example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
  
  tags = {
    Environment = "production"
  }
}
```

### カスタムキャッシュ設定
```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  distribution_name                = "my-distribution"
  s3_bucket_regional_domain_name   = "my-bucket.s3.ap-northeast-1.amazonaws.com"
  origin_id                        = "S3-my-bucket"
  
  price_class                = "PriceClass_100"  # 北米・ヨーロッパのみ
  viewer_protocol_policy     = "https-only"
  compress                   = true
  
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/error.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 403
      response_code         = 403
      response_page_path    = "/error.html"
      error_caching_min_ttl = 10
    }
  ]
  
  tags = {
    Environment = "production"
  }
}
```

## 入力変数

### 必須変数
| 変数名 | 型 | 説明 |
|--------|-----|------|
| `distribution_name` | string | CloudFront Distributionの名前 |
| `s3_bucket_regional_domain_name` | string | S3バケットのリージョナルドメイン名 |

### オプション変数
| 変数名 | 型 | デフォルト | 説明 |
|--------|-----|-----------|------|
| `origin_id` | string | "S3Origin" | オリジンID |
| `enabled` | bool | true | Distributionの有効化 |
| `enable_ipv6` | bool | true | IPv6の有効化 |
| `comment` | string | "" | コメント |
| `default_root_object` | string | "index.html" | デフォルトルートオブジェクト |
| `price_class` | string | "PriceClass_200" | 価格クラス |
| `aliases` | list(string) | [] | カスタムドメイン名 |
| `allowed_methods` | list(string) | ["GET", "HEAD", "OPTIONS"] | 許可するHTTPメソッド |
| `cached_methods` | list(string) | ["GET", "HEAD"] | キャッシュするHTTPメソッド |
| `viewer_protocol_policy` | string | "redirect-to-https" | ビューワープロトコルポリシー |
| `compress` | bool | true | 自動圧縮 |
| `acm_certificate_arn` | string | "" | ACM証明書ARN |
| `minimum_protocol_version` | string | "TLSv1.2_2021" | 最小TLSバージョン |

## 出力値

| 出力名 | 説明 |
|--------|------|
| `distribution_id` | CloudFront DistributionのID |
| `distribution_arn` | CloudFront DistributionのARN |
| `distribution_domain_name` | CloudFrontのドメイン名 |
| `distribution_hosted_zone_id` | CloudFrontのHosted Zone ID |
| `oac_id` | Origin Access ControlのID |
| `oac_arn` | Origin Access ControlのARN |

## 価格クラス

- `PriceClass_All`: 全エッジロケーション（最も高価）
- `PriceClass_200`: 日本、アジア、北米、ヨーロッパ（推奨）
- `PriceClass_100`: 北米、ヨーロッパのみ（最も安価）

## ビューワープロトコルポリシー

- `allow-all`: HTTPとHTTPSの両方を許可
- `https-only`: HTTPSのみ許可
- `redirect-to-https`: HTTPをHTTPSにリダイレクト（推奨）

## カスタムドメイン使用時の注意事項

1. **ACM証明書は us-east-1 リージョンで作成**
   ```bash
   aws acm request-certificate \
     --domain-name www.example.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. **DNS検証を完了**
   - Route 53またはDNSプロバイダーで検証レコードを設定

3. **CloudFront設定で証明書ARNとaliasesを指定**

4. **Route 53でCNAMEまたはAliasレコードを設定**

## キャッシュポリシー

デフォルトでAWSマネージドポリシー `CachingOptimized` を使用。
- TTL: 最小1秒、最大31536000秒（1年）、デフォルト86400秒（1日）
- 圧縮サポート: Gzip, Brotli
- クエリ文字列: なし

カスタムポリシーを使用する場合は `cache_policy_id` を指定。

## トラブルシューティング

### キャッシュクリア
```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

### デプロイ時間
CloudFront Distributionの作成・更新には10〜15分程度かかります。