# 開発用のtfvarsファイル
# terraform apply -var-file="dev.tfvars"

aws_region      = "ap-northeast-1"
environment     = "development"
enable_cloudfront = false  # 開発環境ではS3単体でホスティング
