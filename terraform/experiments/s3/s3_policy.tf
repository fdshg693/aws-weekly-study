# ==============================
# S3バケットのアクセスポリシー設定
# ==============================

# パブリックアクセスブロック設定
# 注意：本番環境ではCloudFront OAI経由を推奨
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # 個々のオブジェクトに対して「誰でもアクセスできる」という設定ができるようになります。
  # false: S3オブジェクトレベルのACL（アクセスコントロールリスト）でパブリックアクセスを許可できます。
  # true: パブリックACLの設定そのものがブロックされます。
  block_public_acls = local.is_production 
  # バケットポリシーでパブリックアクセスを許可できるかどうかを制御します。
  # false: S3バケットポリシーでパブリックアクセスを許可できます。
  # true: パブリックアクセスを許可するポリシーの適用がブロックされます。
  block_public_policy = local.is_production
  # 既存のパブリックACLが有効に機能するかどうかを制御します。
  # false: 既存のパブリックACLが有効に機能します。
  # true: パブリックACLが無視されてアクセスが制限されます。
  ignore_public_acls = local.is_production
  # パブリックポリシーが有効に機能するかどうかを制御します。
  # false: バケットポリシーがパブリックアクセスを許可していれば、それが適用されます。
  # true: パブリックポリシーが有効でもアクセスを制限します。
  restrict_public_buckets = local.is_production
}

# 全員が読み取り可能にするバケットポリシーの設定（開発環境のみ）
resource "aws_s3_bucket_policy" "static_website" {
  # 本番環境ではcountが0になるため、このリソースは作成されない
  count  = local.is_production ? 0 : 1
  bucket = aws_s3_bucket.static_website.id

  # depends_onで明示的な依存関係を定義
  # パブリックアクセスブロックを先に解除してからポリシー適用
  depends_on = [aws_s3_bucket_public_access_block.static_website]

  # バケットポリシーの設定
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # SIDはステートメントの識別子
        Sid       = "PublicReadGetObject"
        # 許可
        Effect    = "Allow"
        # 全員に対して
        Principal = "*"
        # オブジェクトの読み取り権限
        Action    = "s3:GetObject"
        # バケット内のすべて(*)のオブジェクトを対象
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}
