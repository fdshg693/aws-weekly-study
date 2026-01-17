# ============================================================================
# AWS Secrets Manager Configuration for Discord Bot Token
# ============================================================================
# このファイルは Discord Bot Token を安全に保存・管理するための
# AWS Secrets Manager リソースを定義します。
#
# Secrets Manager の利点:
# - 暗号化された状態で保存
# - アクセスログの完全な監査証跡
# - 自動ローテーション機能（オプション）
# - IAM による細かいアクセス制御
# - バージョン管理機能
#
# コスト:
# - シークレットあたり $0.40/月
# - API 呼び出し 10,000 件あたり $0.05
# ============================================================================

# ----------------------------------------------------------------------------
# Random Suffix for Secrets Manager
# ----------------------------------------------------------------------------
# シークレット名の末尾にランダムな文字列を追加します。
#
# 理由:
# - Secrets Manager は削除後も 7-30 日間同じ名前を使用できない
# - 再作成時に名前の衝突を防ぐ
# - 環境の再構築を容易にする
#
# 代替案:
# - recovery_window_in_days = 0 で即座に削除（非推奨、事故防止のため）
# - 固定の名前を使用し、手動で削除期間を待つ
resource "random_id" "secret_suffix" {
  byte_length = 4
}

# ----------------------------------------------------------------------------
# AWS Secrets Manager Secret
# ----------------------------------------------------------------------------
# Discord Bot Token を保存するシークレットを作成します。
#
# ベストプラクティス:
# - 説明を明確に記載
# - 適切なタグを設定して管理を容易にする
# - 本番環境では recovery_window_in_days を長めに設定（30日推奨）
#
# セキュリティ考慮事項:
# - KMS カスタマー管理キーの使用を検討（より高度な制御が必要な場合）
# - リソースポリシーで特定のIAMロールのみアクセス許可
resource "aws_secretsmanager_secret" "discord_bot_token" {
  name        = "${var.project_name}-${var.environment}-discord-token-${random_id.secret_suffix.hex}"
  description = "Discord Bot Token for ${var.project_name} ${var.environment} environment"

  # 削除時の復旧期間（日数）
  # 0: 即座に削除（非推奨）
  # 7-30: 指定日数後に完全削除（推奨）
  # 開発環境では短く、本番環境では長く設定
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-discord-token"
    Environment = var.environment
    Purpose     = "Discord Bot Authentication Token"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Secrets Manager Secret Version
# ----------------------------------------------------------------------------
# シークレットの値を設定します。
#
# 重要な注意事項:
# - Terraform 変数から値を設定
# - 変数の値は terraform.tfvars や環境変数から提供
# - CI/CD パイプラインでは環境変数を使用することを推奨
#
# セキュリティ警告:
# - terraform.tfstate ファイルにシークレットが平文で保存される
# - tfstate ファイルの保護が重要（S3バックエンド + 暗号化）
# - .tfvars ファイルを Git にコミットしない（.gitignore に追加）
#
# 代替案:
# - Terraform 外で aws cli を使用して手動設定
#   aws secretsmanager put-secret-value --secret-id xxx --secret-string "token"
# - AWS Console から手動で値を設定
# - CI/CD パイプラインで環境変数から設定
resource "aws_secretsmanager_secret_version" "discord_bot_token" {
  secret_id = aws_secretsmanager_secret.discord_bot_token.id

  # Discord Bot Token の値
  # local.discord_bot_token から設定
  # 環境変数 TF_VAR_discord_bot_token または python/.env から読み取られます
  secret_string = jsonencode({
    DISCORD_BOT_TOKEN = local.discord_bot_token
  })
}

# ----------------------------------------------------------------------------
# Resource Policy for Secrets Manager (Optional)
# ----------------------------------------------------------------------------
# シークレットへのアクセスをさらに制限するリソースポリシー（オプション）
#
# 用途:
# - 特定の IAM ロールのみアクセス許可
# - 特定の VPC エンドポイント経由のみアクセス許可
# - 条件付きアクセス制御
#
# 以下はコメントアウトされた例です。必要に応じて有効化してください。

# resource "aws_secretsmanager_secret_policy" "discord_bot_token" {
#   secret_arn = aws_secretsmanager_secret.discord_bot_token.arn
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "EnableEC2RoleAccess"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.ec2_role.arn
#         }
#         Action   = "secretsmanager:GetSecretValue"
#         Resource = "*"
#       }
#     ]
#   })
# }

# ----------------------------------------------------------------------------
# Automatic Rotation Configuration (Optional)
# ----------------------------------------------------------------------------
# シークレットの自動ローテーション設定（オプション）
#
# Discord Bot Token は通常手動でローテーションされるため、
# 自動ローテーションは不要ですが、以下のような用途では有用です:
# - データベース認証情報
# - API キー（ローテーションをサポートするサービス）
#
# 実装には Lambda 関数が必要です。

# resource "aws_secretsmanager_secret_rotation" "discord_bot_token" {
#   secret_id           = aws_secretsmanager_secret.discord_bot_token.id
#   rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
#
#   rotation_rules {
#     automatically_after_days = 30
#   }
# }
