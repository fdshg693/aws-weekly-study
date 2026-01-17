# ===========================
# ローカル変数
# ===========================

# 現在のAWSアカウント情報を取得
data "aws_caller_identity" "current" {}

locals {
  # バケット名の生成（アカウントID + リージョンで一意性を確保）
  bucket_name = "static-website-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # 環境判定
  is_production = var.environment == "production"

  # MIMEタイプマッピング
  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "svg"  = "image/svg+xml"
    "gif"  = "image/gif"
    "ico"  = "image/x-icon"
    "txt"  = "text/plain"
  }

  # ウェブサイトファイルのマップを作成
  website_files = {
    # fileset(path, pattern)は、pathからの相対パスでpatternにマッチするファイルのセットを返す
    for file in fileset("${path.module}/website", "**/*") :
    file => {
      key          = file
      source       = "${path.module}/website/${file}"
      content_type = lookup(local.mime_types, split(".", file)[length(split(".", file)) - 1], "application/octet-stream")
    }
  }

  # 共通タグ
  common_tags = {
    Environment = var.environment
    Project     = "StaticWebsite"
    ManagedBy   = "Terraform"
  }
}
