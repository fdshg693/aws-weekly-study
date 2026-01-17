# 静的ウェブサイトホスティング設定

# WEBサイトとしてS3バケットを使用するための設定
resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # ルートドキュメント
  index_document {
    suffix = "index.html"
  }

  # 404エラーページ（オプション）
  error_document {
    key = "error.html"
  }
}
