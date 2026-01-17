# ==============================
# 静的ウェブサイトホスティング設定
# - S3バケットをウェブサイトとして設定
# - 簡単なルーティング（index.html、error.htmlの指定）
# ==============================

# WEBサイトとしてS3バケットを使用するための設定
resource "aws_s3_bucket_website_configuration" "static_website" {
  # 設定を適用するS3バケットの指定
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
