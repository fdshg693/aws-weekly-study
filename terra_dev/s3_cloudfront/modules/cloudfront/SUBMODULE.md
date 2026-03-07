# CloudFront Distribution モジュール

## 概要
S3バケットをオリジンとするCloudFront DistributionとOAC（Origin Access Control）を管理するモジュールです。世界中のエッジロケーションにコンテンツをキャッシュし、ユーザーに高速にコンテンツを配信します。

### 作成物
- **CloudFront Distribution**: CDNを提供するメインリソース
- **Origin Access Control (OAC)**: S3バケットへのセキュアなアクセスを実現
- **カスタムエラーレスポンス**: 4xx/5xxエラー時の動作をカスタマイズ
- **SSL/TLS証明書設定**: HTTPS通信のセキュリティ設定

このモジュールは、S3 Websiteモジュールと組み合わせて使用されます。S3 Websiteモジュールが静的コンテンツを格納し、CloudFrontモジュールがそのコンテンツを世界中に配信する役割を担います。OACにより、S3バケットへの直接アクセスを防ぎ、CloudFront経由のみでコンテンツにアクセスできるようにします。

## 構成ファイル
- [main.tf](main.tf): CloudFront DistributionとOACの定義。キャッシュビヘイビア、エラーレスポンス、地理的制限、SSL/TLS設定などを含む
- [variables.tf](variables.tf): モジュールの入力変数定義。ディストリビューション名、S3バケットドメイン名、キャッシュポリシーなど
- [outputs.tf](outputs.tf): モジュールの出力値定義。DistributionのID、ARN、ドメイン名、OACのID/ARNを出力

## 注意事項
- **ACM証明書のリージョン**: カスタムドメイン用のACM証明書は必ず`us-east-1`リージョンで作成する必要があります
- **OACとバケットポリシー**: CloudFront作成後、S3バケットポリシーでCloudFront DistributionのARNを許可する必要があります
- **デプロイ時間**: CloudFront Distributionの作成・更新には15〜30分程度かかります
- **キャッシュポリシー**: デフォルトではAWSマネージドポリシー「CachingOptimized」を使用しますが、カスタムポリシーIDを指定することも可能です
- **地理的制限**: 特定の国や地域からのアクセスを制限する場合は、`geo_restriction_type`と`geo_restriction_locations`を設定してください
| `default_root_object` | string | "index.html" | デフォルトルートオブジェクト |
| `price_class` | string | "PriceClass_200" | 価格クラス |
| `aliases` | list(string) | [] | カスタムドメイン名 |
| `allowed_methods` | list(string) | ["GET", "HEAD", "OPTIONS"] | 許可するHTTPメソッド |
| `cached_methods` | list(string) | ["GET", "HEAD"] | キャッシュするHTTPメソッド |
| `viewer_protocol_policy` | string | "redirect-to-https" | ビューワープロトコルポリシー |
| `compress` | bool | true | 自動圧縮 |
| `acm_certificate_arn` | string | "" | ACM証明書ARN |
| `minimum_protocol_version` | string | "TLSv1.2_2021" | 最小TLSバージョン |

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