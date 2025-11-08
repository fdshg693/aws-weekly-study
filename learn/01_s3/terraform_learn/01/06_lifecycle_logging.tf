# ライフサイクルポリシーとログ設定
#
# 学習ポイント：
# - S3ライフサイクルルール（移行・削除）
# - S3アクセスログ設定
# - サーバーサイド暗号化
# - バケット通知（イベント）

# ログ保存用バケット
resource "aws_s3_bucket" "logs" {
  bucket = "static-website-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Website Access Logs"
    Environment = "Learning"
  }
}

# ログバケットのACL設定（ログ配信用）
resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"
}

# メインバケットのログ設定
resource "aws_s3_bucket_logging" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

# ライフサイクルポリシー：古いログファイルの自動削除・移行
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    # 90日後にGlacierに移行
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # 365日後に削除
    expiration {
      days = 365
    }
  }

  rule {
    id     = "clean-incomplete-multipart-uploads"
    status = "Enabled"

    # 未完了のマルチパートアップロードを7日後に削除
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# メインバケットのライフサイクル：旧バージョン管理
resource "aws_s3_bucket_lifecycle_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    # 非現行バージョンを30日後に削除
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # 非現行バージョンを7日後にInfrequent Accessに移行
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "STANDARD_IA"
    }
  }
}

# サーバーサイド暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # S3管理キー
      # KMS使用時
      # sse_algorithm     = "aws:kms"
      # kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true # バケットキー有効化（コスト削減）
  }
}

# S3イベント通知例（SNS/SQS/Lambda連携）
# resource "aws_s3_bucket_notification" "static_website" {
#   bucket = aws_s3_bucket.static_website.id
#
#   # Lambdaトリガー例
#   lambda_function {
#     lambda_function_arn = aws_lambda_function.processor.arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_prefix       = "uploads/"
#     filter_suffix       = ".jpg"
#   }
#
#   # SNSトピック例
#   topic {
#     topic_arn = aws_sns_topic.bucket_notifications.arn
#     events    = ["s3:ObjectRemoved:*"]
#   }
#
#   depends_on = [
#     aws_lambda_permission.allow_bucket,
#     aws_sns_topic_policy.allow_bucket
#   ]
# }
