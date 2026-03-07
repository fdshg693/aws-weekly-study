# ============================================================================
# IAM Configuration for Discord Chatbot EC2 Instance
# ============================================================================
# このファイルはDiscord ChatbotをホストするEC2インスタンスに必要な
# IAMロール、ポリシー、インスタンスプロファイルを定義します。

# ----------------------------------------------------------------------------
# IAM Role for EC2 Instance
# ----------------------------------------------------------------------------
# EC2インスタンスにアタッチするIAMロールを作成します。
# 
# ベストプラクティス:
# - 最小権限の原則に従い、必要な権限のみを付与
# - 信頼ポリシーでは適切なサービスプリンシパルのみを許可
# - ロール名は目的が明確にわかるように命名
#
# 代替案:
# - 既存のIAMロールを使用する場合は、data sourceで参照可能
resource "aws_iam_role" "ec2_role" {
  name        = "discord-chatbot-ec2-role"
  description = "IAM role for Discord Chatbot EC2 instance with SSM and CloudWatch access"

  # AssumeRoleポリシー: どのAWSサービスがこのロールを引き受けられるかを定義
  # ここではEC2サービスのみがこのロールを使用できるように設定
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "discord-chatbot-ec2-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# AWS Managed Policy Attachment: SSM Access
# ----------------------------------------------------------------------------
# AWS管理ポリシー「AmazonSSMManagedInstanceCore」をアタッチします。
# このポリシーにより、Session Managerを使用してインスタンスに接続できます。
#
# 含まれる権限:
# - SSM Agent の基本機能
# - Session Manager による接続
# - Systems Manager のコマンド実行
#
# 利点:
# - SSH鍵やバスティオンホストが不要
# - セキュアな接続（すべての通信が暗号化）
# - アクセスログが自動的に記録
#
# 代替案:
# - カスタムポリシーで必要な権限のみを付与することも可能
# - より制限が必要な場合は、条件キーを使用して制御
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ----------------------------------------------------------------------------
# Custom Policy: CloudWatch Logs Write Access
# ----------------------------------------------------------------------------
# CloudWatch Logsへのログ書き込み権限を付与するカスタムポリシー
#
# ベストプラクティス:
# - リソースを可能な限り制限（特定のロググループに限定）
# - 必要最小限のアクションのみを許可
# - 条件を使用してさらに制限することも可能
#
# このポリシーで許可されるアクション:
# 1. ログストリームの作成
# 2. ログイベントの送信
# 3. ログストリームの説明取得
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "discord-chatbot-cloudwatch-logs-policy"
  description = "Allows EC2 instance to write logs to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",    # ロググループ内に新しいログストリームを作成
          "logs:PutLogEvents",        # ログイベントをログストリームに書き込み
          "logs:DescribeLogStreams"   # ログストリームの情報を取得
        ]
        # リソースの制限:
        # 特定のロググループのみにアクセスを制限することを推奨
        # 現在はすべてのロググループを許可していますが、本番環境では制限してください
        # 例: "arn:aws:logs:*:*:log-group:/aws/ec2/discord-chatbot:*"
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/ec2/*",
          "arn:aws:logs:*:*:log-group:/aws/ec2/*:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"  # ロググループの作成権限（初回のみ必要）
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/*"
      }
    ]
  })

  tags = {
    Name        = "discord-chatbot-cloudwatch-logs-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Logsポリシーのアタッチ
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# ----------------------------------------------------------------------------
# Secrets Manager Access Policy
# ----------------------------------------------------------------------------
# Secrets Managerからシークレットを読み取る権限
#
# 用途:
# - Discord Bot Token などの機密情報を安全に保存・取得
# - データベース認証情報の管理
# - API キーなどの外部サービス認証情報
#
# ベストプラクティス:
# - 特定のシークレットARNに限定する
# - タグベースのアクセス制御を使用する
# - ローテーション機能を活用する
#
# セキュリティ:
# - GetSecretValue: シークレットの値を取得（最も機密性の高い操作）
# - DescribeSecret: シークレットのメタデータのみ取得（値は含まない）
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "discord-chatbot-secrets-manager-policy"
  description = "Allows EC2 instance to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue", # シークレットの値を取得
          "secretsmanager:DescribeSecret"  # シークレットのメタデータを取得
        ]
        # セキュリティのため、特定のシークレットに限定
        # プロジェクト名をプレフィックスとして使用
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}-*"
      }
    ]
  })

  tags = {
    Name        = "discord-chatbot-secrets-manager-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_manager" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

# ----------------------------------------------------------------------------
# S3 Access Policy
# ----------------------------------------------------------------------------
# S3バケットからアプリケーションファイルを読み取る権限
#
# 用途:
# - Botスクリプト（echo.py）のダウンロード
# - 設定ファイルや依存関係ファイルの取得
# - アプリケーション更新時の最新ファイル取得
#
# ベストプラクティス:
# - 読み取り専用権限のみを付与（書き込み権限は不要）
# - 特定のバケットに限定
# - オブジェクトレベルのアクセス制御
#
# セキュリティ:
# - GetObject: オブジェクトの内容を取得
# - ListBucket: バケット内のオブジェクト一覧を取得（オプション）
resource "aws_iam_policy" "s3_read_policy" {
  name        = "discord-chatbot-s3-read-policy"
  description = "Allows EC2 instance to read application files from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",     # オブジェクトの読み取り
          "s3:GetObjectVersion" # バージョン管理されたオブジェクトの読み取り
        ]
        # 特定のバケットのみにアクセス制限
        # ${var.project_name}-${var.environment}-assets バケット内のすべてのオブジェクト
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-assets/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket" # バケット内のオブジェクト一覧を取得
        ]
        # バケット自体へのアクセス（オブジェクトではない）
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-assets"
      }
    ]
  })

  tags = {
    Name        = "discord-chatbot-s3-read-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# ----------------------------------------------------------------------------
# Optional: SSM Parameter Store Access (Future Extension)
# ----------------------------------------------------------------------------
# 将来の拡張用：SSM Parameter Storeからパラメータを読み取る権限
# 使用する場合は、以下のコメントを解除してください
#
# 用途:
# - アプリケーション設定値の管理
# - 環境変数の一元管理
# - 機密性の低い設定情報の保存
#
# Secrets Manager vs Parameter Store:
# - Secrets Manager: 自動ローテーション、より高いセキュリティ、コスト高
# - Parameter Store: シンプル、低コスト、基本的な暗号化
#
# ベストプラクティス:
# - 階層構造を使用して管理（例：/discord-chatbot/prod/config）
# - 特定のパスプレフィックスに限定する

# resource "aws_iam_policy" "ssm_parameter_store_policy" {
#   name        = "discord-chatbot-ssm-parameter-store-policy"
#   description = "Allows EC2 instance to read parameters from SSM Parameter Store"
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ssm:GetParameter",           # 単一パラメータの取得
#           "ssm:GetParameters",          # 複数パラメータの一括取得
#           "ssm:GetParametersByPath",    # パス配下のパラメータを取得
#           "ssm:DescribeParameters"      # パラメータのメタデータを取得
#         ]
#         # パスプレフィックスで制限することを推奨
#         # 例: "arn:aws:ssm:region:account-id:parameter/discord-chatbot/*"
#         Resource = "arn:aws:ssm:*:*:parameter/discord-chatbot/*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt"  # 暗号化されたパラメータを復号化
#         ]
#         # KMSキーを特定することを推奨
#         # 現在はデフォルトのSSM KMSキーを使用
#         Resource = "arn:aws:kms:*:*:key/*"
#         Condition = {
#           StringEquals = {
#             "kms:ViaService" = "ssm.*.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })
#
#   tags = {
#     Name        = "discord-chatbot-ssm-parameter-store-policy"
#     Environment = var.environment
#     ManagedBy   = "Terraform"
#   }
# }
#
# resource "aws_iam_role_policy_attachment" "ssm_parameter_store" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = aws_iam_policy.ssm_parameter_store_policy.arn
# }

# ----------------------------------------------------------------------------
# Instance Profile
# ----------------------------------------------------------------------------
# IAMインスタンスプロファイル：EC2インスタンスにIAMロールをアタッチするために必要
#
# 重要:
# - IAMロールを直接EC2にアタッチすることはできません
# - インスタンスプロファイルを介してロールをアタッチする必要があります
# - 1つのインスタンスプロファイルには1つのIAMロールのみを含めることができます
#
# 使用方法:
# - EC2インスタンスのリソース定義でiam_instance_profileパラメータに指定
# - 例: iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "discord-chatbot-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "discord-chatbot-ec2-profile"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
