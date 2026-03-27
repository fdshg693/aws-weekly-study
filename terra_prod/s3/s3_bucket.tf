# S3バケット本体とバージョニング設定

# リソースが存在しない -> s3バケットを作成するリソースブロック
# リソースが既に存在する -> 変更が必要な場合（この場合はタグ）にのみ更新
resource "aws_s3_bucket" "static_website" {
  bucket = local.bucket_name

  tags = local.resource_tags.static_website
}

# バージョニング設定（別リソースとして分離）
# Terraform AWS Provider v4以降の推奨方式
resource "aws_s3_bucket_versioning" "static_website" {
  # 前に定義したS3バケットを参照して、指定する
  bucket = aws_s3_bucket.static_website.id

  # バージョニング設定を有効化
  versioning_configuration {
    status = local.current_env.versioning_status
  }
}
