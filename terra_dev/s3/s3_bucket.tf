# S3バケット本体とバージョニング設定

# リソースが存在しない -> s3バケットを作成するリソースブロック
# リソースが既に存在する -> 変更が必要な場合（この場合はタグ）にのみ更新
resource "aws_s3_bucket" "static_website" {
  bucket = local.bucket_name

  # タグをつけることで、タグごとの管理やコスト配分がしやすくなる
  tags = {
    Name        = "Static Website Bucket"
    Environment = "Learning"
    Purpose     = "simple static website hosting"
  }
}

# バージョニング設定（別リソースとして分離）
# Terraform AWS Provider v4以降の推奨方式
resource "aws_s3_bucket_versioning" "static_website" {
  # 前に定義したS3バケットを参照して、指定する
  bucket = aws_s3_bucket.static_website.id

  # バージョニング設定を有効化
  versioning_configuration {
    # 本番環境ではバージョニングを有効化、開発環境では一時停止
    status = local.is_production ? "Enabled" : "Suspended"
  }
}
