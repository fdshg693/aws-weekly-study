# ============================================================================
# S3 Bucket Configuration for Discord Chatbot Assets
# ============================================================================
# このファイルは Discord Chatbot アプリケーションファイルを保存する
# S3バケットを定義します。
#
# 格納されるファイル:
# - echo.py: Discord Bot のメインアプリケーション
# - その他の将来的な設定ファイルやスクリプト
#
# セキュリティ設定:
# - プライベートアクセスのみ許可
# - バージョニング有効化（ファイル更新履歴管理）
# - サーバーサイド暗号化（SSE-S3）
# ============================================================================

# ----------------------------------------------------------------------------
# S3 Bucket for Bot Application Files
# ----------------------------------------------------------------------------
# アプリケーションファイルを保存するS3バケットを作成します。
#
# ベストプラクティス:
# - バケット名はグローバルで一意である必要がある
# - 環境ごとに異なるバケットを使用
# - ライフサイクルポリシーで古いバージョンを自動削除
#
# コスト最適化:
# - 小さいファイル（echo.py）なので月額コストは数セント程度
# - 頻繁にアクセスされないため、Standard クラスで十分
resource "aws_s3_bucket" "bot_assets" {
  bucket = "${var.project_name}-${var.environment}-assets"

  # force_destroy = true にすると、バケットが空でなくても削除可能
  # 開発環境では便利だが、本番環境では false を推奨
  force_destroy = var.environment == "prod" ? false : true

  tags = {
    Name        = "${var.project_name}-${var.environment}-assets"
    Environment = var.environment
    Purpose     = "Discord Bot Application Files"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# S3 Bucket Versioning Configuration
# ----------------------------------------------------------------------------
# バージョニングを有効化して、ファイルの更新履歴を保持します。
#
# メリット:
# - 誤って上書きした場合に過去のバージョンに復元可能
# - デプロイ失敗時のロールバックが容易
# - 監査証跡として使用可能
#
# 注意点:
# - 古いバージョンもストレージを消費（コスト増）
# - ライフサイクルルールで古いバージョンを自動削除することを推奨
resource "aws_s3_bucket_versioning" "bot_assets" {
  bucket = aws_s3_bucket.bot_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ----------------------------------------------------------------------------
# S3 Bucket Server-Side Encryption
# ----------------------------------------------------------------------------
# サーバーサイド暗号化を有効化して、保存データを暗号化します。
#
# 暗号化オプション:
# - SSE-S3 (AES-256): AWS管理の暗号化キー（追加コストなし）
# - SSE-KMS: カスタマー管理キー、より高度な制御、監査可能（追加コスト）
# - SSE-C: クライアント提供の暗号化キー（管理が複雑）
#
# ベストプラクティス:
# - 最低でも SSE-S3 を使用
# - コンプライアンス要件がある場合は SSE-KMS を検討
resource "aws_s3_bucket_server_side_encryption_configuration" "bot_assets" {
  bucket = aws_s3_bucket.bot_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3
    }
  }
}

# ----------------------------------------------------------------------------
# S3 Bucket Public Access Block
# ----------------------------------------------------------------------------
# パブリックアクセスを完全にブロックします。
#
# セキュリティ設定の説明:
# - block_public_acls: 新しいパブリックACLをブロック
# - block_public_policy: 新しいパブリックバケットポリシーをブロック
# - ignore_public_acls: 既存のパブリックACLを無視
# - restrict_public_buckets: パブリックポリシーを持つバケットへのアクセス制限
#
# ベストプラクティス:
# - すべて true に設定することを強く推奨（AWS デフォルト設定）
# - パブリックアクセスが必要な場合は CloudFront 経由で提供
resource "aws_s3_bucket_public_access_block" "bot_assets" {
  bucket = aws_s3_bucket.bot_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------------------------
# S3 Bucket Lifecycle Rule (Optional)
# ----------------------------------------------------------------------------
# 古いバージョンのファイルを自動削除してストレージコストを削減します。
#
# ルール:
# - 非カレントバージョン（古いバージョン）を30日後に削除
# - 削除マーカーが唯一のバージョンの場合は削除
#
# カスタマイズ例:
# - 本番環境では保持期間を長くする（90日など）
# - Glacier に移行してコスト削減（アーカイブ用途）
resource "aws_s3_bucket_lifecycle_configuration" "bot_assets" {
  bucket = aws_s3_bucket.bot_assets.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    # フィルター: すべてのオブジェクトに適用
    filter {}

    # 非カレントバージョンの削除
    noncurrent_version_expiration {
      noncurrent_days = var.s3_old_version_retention_days
    }

    # 期限切れのオブジェクトの削除マーカーを削除
    expiration {
      expired_object_delete_marker = true
    }
  }
}

# ----------------------------------------------------------------------------
# S3 Object: Upload echo.py
# ----------------------------------------------------------------------------
# echo.py ファイルをS3バケットにアップロードします。
#
# 動作:
# - Terraform apply 実行時に自動的にアップロード
# - ファイルが変更されると自動的に再アップロード（ETag で検出）
#
# ベストプラクティス:
# - content_type を正確に設定
# - ETag を使用して変更検出
# - 本番環境では CI/CD パイプラインでのアップロードも検討
resource "aws_s3_object" "echo_py" {
  bucket = aws_s3_bucket.bot_assets.id
  key    = "scripts/echo.py"
  source = "${path.module}/python/echo.py"

  # ファイルの変更を検出するための ETag
  # ファイルが変更されると自動的に再アップロード
  etag = filemd5("${path.module}/python/echo.py")

  # コンテンツタイプの設定
  content_type = "text/x-python"

  tags = {
    Name        = "discord-bot-echo-script"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# S3 Object: Upload requirements.txt (Optional)
# ----------------------------------------------------------------------------
# Python の依存関係を定義した requirements.txt をアップロードします。
# ファイルが存在する場合のみアップロードされます。
#
# 用途:
# - 依存パッケージのバージョン管理
# - 環境の再現性確保
# - pip install -r requirements.txt で一括インストール
resource "aws_s3_object" "requirements_txt" {
  # ファイルが存在する場合のみリソースを作成
  count = fileexists("${path.module}/python/requirements.txt") ? 1 : 0

  bucket = aws_s3_bucket.bot_assets.id
  key    = "scripts/requirements.txt"
  source = "${path.module}/python/requirements.txt"

  etag         = filemd5("${path.module}/python/requirements.txt")
  content_type = "text/plain"

  tags = {
    Name        = "discord-bot-requirements"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
