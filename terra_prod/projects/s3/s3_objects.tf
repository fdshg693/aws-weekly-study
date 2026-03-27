# ==============================
# S3バケットへのファイルアップロード設定
# ==============================

# for_eachを使った複数ファイルアップロード
# 実践的なパターン：MIMEタイプマッピング

# 複数ファイルをループでアップロード
resource "aws_s3_object" "website_files" {
  # for_eachでset,list,mapなどのコレクションをループ処理
  # 今回は、setであるlocal.website_filesをループ
  # 後続で、each.valueで各要素にアクセス可能
  for_each = local.website_files
  
  # アップロード先のバケットを指定
  bucket       = aws_s3_bucket.static_website.id
  # keyとは、S3バケット内でのオブジェクトのパス（キー）のこと
  # 今回は、websiteフォルダ内の相対パスをそのままS3のキーとして使用
  key          = each.value
  # ファイルのコンテンツソース
  # 今回は、websiteフォルダ内の各ファイルを指定
  source       = "${path.module}/website/${each.value}"
  # MIMEタイプを設定
  # split(".", each.value)[length(split(".", each.value)) - 1],で拡張子を取得
  # LOOKUP関数で、拡張子に対応するMIMEタイプをlocal.mime_typesから取得
  # 見つからない場合は、application/octet-streamをデフォルトで使用
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  # 変更検知用のETagを設定
  # filemd5関数で、ファイルのMD5ハッシュを計算
  etag         = filemd5("${path.module}/website/${each.value}")
}
