# ==============================
# S3バケットのアクセスポリシー設定
# ==============================

data "aws_iam_policy_document" "static_website" {
  dynamic "statement" {
    for_each = local.current_env.enforce_secure_transport ? [1] : []

    content {
      sid    = "DenyInsecureTransport"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions = ["s3:*"]

      resources = [
        aws_s3_bucket.static_website.arn,
        "${aws_s3_bucket.static_website.arn}/*",
      ]

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.current_env.public_read_enabled ? [1] : []

    content {
      sid    = "AllowPublicReadGetObject"
      effect = "Allow"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions = ["s3:GetObject"]

      resources = [
        "${aws_s3_bucket.static_website.arn}/*",
      ]
    }
  }
}

# パブリックアクセスブロック設定
# development は S3 Website 経由の確認用に公開、staging / production は private origin 前提
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # 個々のオブジェクトに対して「誰でもアクセスできる」という設定ができるようになります。
  # false: S3オブジェクトレベルのACL（アクセスコントロールリスト）でパブリックアクセスを許可できます。
  # true: パブリックACLの設定そのものがブロックされます。
  block_public_acls = !local.current_env.public_read_enabled
  # バケットポリシーでパブリックアクセスを許可できるかどうかを制御します。
  # false: S3バケットポリシーでパブリックアクセスを許可できます。
  # true: パブリックアクセスを許可するポリシーの適用がブロックされます。
  block_public_policy = !local.current_env.public_read_enabled
  # 既存のパブリックACLが有効に機能するかどうかを制御します。
  # false: 既存のパブリックACLが有効に機能します。
  # true: パブリックACLが無視されてアクセスが制限されます。
  ignore_public_acls = !local.current_env.public_read_enabled
  # パブリックポリシーが有効に機能するかどうかを制御します。
  # false: バケットポリシーがパブリックアクセスを許可していれば、それが適用されます。
  # true: パブリックポリシーが有効でもアクセスを制限します。
  restrict_public_buckets = !local.current_env.public_read_enabled
}

resource "aws_s3_bucket_policy" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # depends_onで明示的な依存関係を定義
  # パブリックアクセスブロックを先に解除してからポリシー適用
  depends_on = [aws_s3_bucket_public_access_block.static_website]

  policy = data.aws_iam_policy_document.static_website.json
}
