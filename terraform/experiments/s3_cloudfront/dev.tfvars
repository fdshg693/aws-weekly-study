# ==============================
# - CloudFront無効
# - S3パブリックアクセス許可
# - バージョニング無効
# - HTTPアクセス
# ==============================

aws_region      = "ap-northeast-1"
environment     = "development"
enable_cloudfront = false  # 開発環境ではS3単体でホスティング
