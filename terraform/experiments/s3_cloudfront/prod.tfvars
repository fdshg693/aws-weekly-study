# ==============================
# - CloudFront有効
# - S3プライベート（OAC経由アクセスのみ）
# - バージョニング有効
# - HTTPSアクセス
# - グローバルCDN配信
# ==============================

aws_region            = "ap-northeast-1"
environment           = "production"
enable_cloudfront     = true   # 本番環境ではCloudFrontを有効化
cloudfront_price_class = "PriceClass_200"  # 日本・アジア・北米・ヨーロッパ

# カスタムドメイン使用時は以下をコメント解除して設定
# custom_domain_names   = ["www.example.com"]
# acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
