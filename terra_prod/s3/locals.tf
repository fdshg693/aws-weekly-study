# ==============================
# ローカル変数の定義
# - ユニークな固定バケット名の生成
# - MIMEタイプマッピング（ファイルアップロード時に使用）
# - S3にアップロードするwebsiteフォルダ内の全ファイルリストの取得
# - 環境判定（本番/開発）
# ==============================

# dataブロックは、既存のリソースや外部データソースから情報を取得するために使用されます。（新しいリソースの作成は行いません）
# aws_caller_identity は、現在AWSにアクセスしているユーザーやロールの情報を取得するデータソースです。
# current は、このデータソースに付けた名前（識別子）です
# 現在のAWSアカウントID・認証情報のARN・ユーザーまたはロールの一意のIDを取得できる
data "aws_caller_identity" "current" {}

# バケット名に使用するローカル変数
# 参照時は、local.??のようにアクセスして、localsでないことに注意
locals {
  # 上のdataブロックと、TFVARSで指定されたリージョン変数を組み合わせて一意のバケット名を生成
  bucket_name = "static-website-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # MIMEタイプマッピング
  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "svg"  = "image/svg+xml"
  }

  # websiteフォルダ内の全ファイルリストを取得
  # 実際に使う場合は fileset() 関数で動的に取得
  # ${path.module}は、現在のモジュール（この場合はterraform/s3ディレクトリ）のパスを指す組み込み変数
  # "**/*" は、サブディレクトリも含めた全てのファイルを対象とするワイルドカードパターン
  website_files = fileset("${path.module}/website", "**/*")

  # 本番環境下、開発環境下判定する
  is_production = var.environment == "production"
}
