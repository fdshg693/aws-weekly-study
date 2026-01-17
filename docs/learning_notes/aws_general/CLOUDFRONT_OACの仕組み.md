CloudFrontのOAC (Origin Access Control) について詳しく説明します。

## OACとは

OACは、CloudFrontディストリビューションからS3バケットへのアクセスを制御するための仕組みです。S3オリジンへのアクセスをCloudFront経由のみに制限し、直接的なS3へのアクセスを防ぐことができます。

## OACの仕組み

**1. 認証フロー**
- CloudFrontがS3にリクエストを送る際、AWS Signature Version 4 (SigV4) を使って署名します
- この署名により、リクエストがCloudFrontから来たことをS3が検証できます
- S3バケットポリシーで、特定のCloudFrontディストリビューションからのアクセスのみを許可します

**2. バケットポリシーの設定**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::account-id:distribution/distribution-id"
        }
      }
    }
  ]
}
```

## OAC vs OAI (Origin Access Identity)

OACは古いOAIの後継として推奨されています：

**OACの利点:**
- すべてのS3リージョンをサポート
- SSE-KMS暗号化されたオブジェクトをサポート
- より強力な認証 (SigV4)
- S3 Object Lambdaのサポート
- より細かいアクセス制御が可能

## セキュリティ上の重要ポイント

**S3バケットのパブリックアクセスをブロック:**
OACを使用する場合、S3バケット自体はパブリックアクセスをブロックすべきです。これにより、CloudFront経由でのみコンテンツにアクセス可能になります。

**条件付きアクセス:**
`AWS:SourceArn` 条件を使用することで、特定のCloudFrontディストリビューションからのアクセスのみを許可できます。

## 設定手順の概要

1. CloudFrontでOACを作成
2. ディストリビューションのオリジン設定でOACを関連付け
3. S3バケットポリシーを更新してCloudFrontからのアクセスを許可
4. S3バケットのパブリックアクセスをブロック

この仕組みにより、コンテンツへの不正アクセスを防ぎ、CloudFrontを通じた配信のみを許可する安全な構成が実現できます。

何か特定の部分についてさらに詳しく知りたいことはありますか?