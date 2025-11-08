# S3オブジェクトアップロード例
#
# 学習ポイント：
# - Terraformでファイルをアップロードする方法
# - Content-Type（MIME type）の設定
# - ETag（ハッシュ値）によるファイル変更検知
# - for_eachを使った複数ファイル管理

# 単一ファイルアップロード例
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "index.html"
  content_type = "text/html"
  
  # インライン方式：直接コンテンツを記述
  content = <<-EOT
    <!DOCTYPE html>
    <html lang="ja">
    <head>
      <meta charset="UTF-8">
      <title>S3 Static Website</title>
      <link rel="stylesheet" href="style.css">
    </head>
    <body>
      <h1>Welcome to S3 Static Website</h1>
      <p>This is hosted on AWS S3!</p>
    </body>
    </html>
  EOT

  # ETag（MD5ハッシュ）でコンテンツ変更を検知
  etag = md5(<<-EOT
    <!DOCTYPE html>
    <html lang="ja">
    <head>
      <meta charset="UTF-8">
      <title>S3 Static Website</title>
      <link rel="stylesheet" href="style.css">
    </head>
    <body>
      <h1>Welcome to S3 Static Website</h1>
      <p>This is hosted on AWS S3!</p>
    </body>
    </html>
  EOT
  )
}

# ファイルソース方式：ローカルファイルをアップロード
# resource "aws_s3_object" "style_css" {
#   bucket       = aws_s3_bucket.static_website.id
#   key          = "style.css"
#   source       = "${path.module}/assets/style.css"
#   content_type = "text/css"
#   etag         = filemd5("${path.module}/assets/style.css")
# }

# for_eachを使った複数ファイルアップロード
# 実践的なパターン：MIMEタイプマッピング
locals {
  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "svg"  = "image/svg+xml"
  }

  # アップロードするファイルのマップ
  # 実際に使う場合は fileset() 関数で動的に取得
  # website_files = fileset("${path.module}/website", "**/*")
}

# 複数ファイルをループでアップロード（テンプレート）
# resource "aws_s3_object" "website_files" {
#   for_each = local.website_files
#   
#   bucket       = aws_s3_bucket.static_website.id
#   key          = each.value
#   source       = "${path.module}/website/${each.value}"
#   content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
#   etag         = filemd5("${path.module}/website/${each.value}")
# }
