# S3 bucket for Kendra S3 data source
#
# 目的:
# - Amazon Kendra の S3 Data Source (S3 connector) 用のバケットを用意します。
# - TODO#2 の範囲では「バケット作成」まで。Kendra 側の Data Source 設定や IAM の S3 権限付与は
#   TODO#3 で実施します。
#
# 設計方針（最小・安全寄り）:
# - Public access は全面ブロック
# - 暗号化は SSE-S3 (AES256)
# - Ownership controls は BucketOwnerEnforced（ACL を無効化し、所有権を強制）

resource "aws_s3_bucket" "kendra" {
  bucket = var.s3_bucket_name
}

# Block Public Access
# - 意図せず公開状態になるのを防ぐため、4項目すべて true
resource "aws_s3_bucket_public_access_block" "kendra" {
  bucket = aws_s3_bucket.kendra.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Default encryption (SSE-S3)
# - KMS を使う場合は aws_kms_key を別途用意し、SSE-KMS に切り替えます
resource "aws_s3_bucket_server_side_encryption_configuration" "kendra" {
  bucket = aws_s3_bucket.kendra.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Ownership controls
# - BucketOwnerEnforced: ACL を無効化し、バケット所有者を強制します
resource "aws_s3_bucket_ownership_controls" "kendra" {
  bucket = aws_s3_bucket.kendra.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
