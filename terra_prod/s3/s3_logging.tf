# ==============================
# アクセスログ管理
# - 静的ウェブサイト用S3バケットのサーバーアクセスログを有効化
# - ログ専用バケットを分離して作成
# - ログの保管コストを抑えるためのライフサイクル設定を追加
# ==============================

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.access_logs.arn,
      "${aws_s3_bucket.access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowS3ServerAccessLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.access_logs.arn}/${local.s3_access_log_prefix}*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.static_website.arn]
    }
  }
}

# ログ専用バケット
resource "aws_s3_bucket" "access_logs" {
  bucket = local.log_bucket_name

  tags = local.resource_tags.access_logs
}

# ログバケットは非公開にする
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLを使わずバケット所有者を明確にする
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json

  depends_on = [
    aws_s3_bucket_public_access_block.access_logs,
    aws_s3_bucket_ownership_controls.access_logs,
  ]
}

# 静的ウェブサイト用バケットのサーバーアクセスログを専用バケットへ配送
resource "aws_s3_bucket_logging" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = local.s3_access_log_prefix

  target_object_key_format {
    partitioned_prefix {
      partition_date_source = "EventTime"
    }
  }

  depends_on = [aws_s3_bucket_policy.access_logs]
}

# ログは一定期間保管した後に低頻度アクセス階層へ移し、最終的に削除
# ログバケット自体にはアクセスログを設定しない（無限ループ防止）
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access-log-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = var.access_log_transition_to_standard_ia_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.access_log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.access_log_abort_incomplete_multipart_days
    }
  }
}