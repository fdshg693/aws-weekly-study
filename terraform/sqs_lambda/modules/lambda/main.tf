#===============================================================================
# Lambda モジュール - main.tf
#===============================================================================
# このモジュールは、AWS Lambda 関数と関連リソースを作成する汎用モジュールです。
# Producer Lambda と Consumer Lambda の両方で再利用できるように設計されています。
#
# Lambda の実行モデル:
# - Lambda はイベント駆動型のサーバーレスコンピューティングサービス
# - コードは「コールドスタート」時にコンテナにロードされ、実行される
# - 一定時間アイドル状態が続くとコンテナは破棄される（ウォームスタート vs コールドスタート）
# - 同時実行数を制限することで、下流システムへの負荷を制御できる
#===============================================================================

#-------------------------------------------------------------------------------
# Data Sources
#-------------------------------------------------------------------------------

# Lambda コードを ZIP ファイルにアーカイブする
# Terraform が自動的にソースコードをパッケージングしてくれる
data "archive_file" "lambda_zip" {
  type = "zip"

  # ZIP 化するソースディレクトリ
  # source_path には Lambda 関数のコードが含まれるディレクトリを指定
  source_dir = var.source_path

  # 出力先の ZIP ファイルパス
  # path.module はこのモジュールのディレクトリパスを指す
  output_path = "${path.module}/tmp/${var.function_name}.zip"

  # 注意: 
  # - source_dir 内のすべてのファイルが ZIP に含まれる
  # - Python の場合、依存ライブラリも含める必要がある（Lambda Layer 推奨）
  # - ファイルが変更されると自動的に再パッケージングされる
}

# Lambda 用の信頼ポリシー（Assume Role Policy）
# どのサービスがこのロールを引き受けられるかを定義
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  # 解説:
  # - AssumeRole は「ロールを引き受ける」という意味
  # - Lambda サービスがこのロールを使って AWS リソースにアクセスする
  # - principals で Lambda サービスのみに制限している
}

#-------------------------------------------------------------------------------
# CloudWatch Log Group
#-------------------------------------------------------------------------------
# Lambda 関数のログを保存するロググループ
# Lambda 関数名に基づいて自動的に作成される
resource "aws_cloudwatch_log_group" "lambda" {
  # Lambda のログは /aws/lambda/{関数名} というパスに出力される（AWS の規約）
  name = "/aws/lambda/${var.function_name}"

  # ログの保持期間（日数）
  # 開発環境では短め（7日）、本番環境では長め（30日以上）が推奨
  # コスト削減のため、不要になったログは自動削除される
  retention_in_days = var.log_retention_days

  # タグを付与
  tags = merge(
    {
      Name        = "${var.function_name}-logs"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # 解説:
  # - ロググループを事前に作成しておくことで、保持期間を制御できる
  # - Lambda が自動作成するロググループは保持期間が無期限になる
  # - KMS 暗号化も設定可能（本番環境では推奨）
}

#-------------------------------------------------------------------------------
# IAM Role
#-------------------------------------------------------------------------------
# Lambda 関数が AWS リソースにアクセスするための実行ロール
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

  # 信頼ポリシー: Lambda サービスがこのロールを引き受けることを許可
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    {
      Name        = "${var.function_name}-role"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # 解説:
  # - IAM ロールは「誰が」「何をできるか」を定義する
  # - assume_role_policy: 「誰が」このロールを使えるか（信頼ポリシー）
  # - アタッチされたポリシー: 「何ができるか」（権限ポリシー）
}

#-------------------------------------------------------------------------------
# IAM Policy - 基本権限（CloudWatch Logs）
#-------------------------------------------------------------------------------
# Lambda 関数がログを出力するための最低限の権限
resource "aws_iam_policy" "basic" {
  name        = "${var.function_name}-basic-policy"
  description = "Basic policy for Lambda function ${var.function_name} - CloudWatch Logs permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsPermissions"
        Effect = "Allow"
        Action = [
          # ログストリームの作成権限
          "logs:CreateLogStream",
          # ログイベントの書き込み権限
          "logs:PutLogEvents"
        ]
        # このログループに対してのみ権限を付与（最小権限の原則）
        Resource = [
          "${aws_cloudwatch_log_group.lambda.arn}",
          "${aws_cloudwatch_log_group.lambda.arn}:*"
        ]
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.function_name}-basic-policy"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # 解説:
  # - 最小権限の原則: 必要最低限の権限のみを付与
  # - logs:CreateLogGroup は不要（ロググループは Terraform で作成済み）
  # - Resource で特定のロググループのみに制限している
}

# 基本ポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.basic.arn
}

#-------------------------------------------------------------------------------
# IAM Policy - 追加権限（SQS、DynamoDB など）
#-------------------------------------------------------------------------------
# 動的に追加のポリシーを作成・アタッチ
# Producer は SQS 送信権限、Consumer は SQS 受信権限など

# 追加ポリシーの作成
resource "aws_iam_policy" "additional" {
  # count を使って、追加ポリシーがある場合のみリソースを作成
  count = length(var.additional_policies)

  name        = "${var.function_name}-additional-policy-${count.index}"
  description = "Additional policy ${count.index} for Lambda function ${var.function_name}"

  # 渡されたポリシー JSON をそのまま使用
  policy = var.additional_policies[count.index]

  tags = merge(
    {
      Name        = "${var.function_name}-additional-policy-${count.index}"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # 解説:
  # - count.index で複数のポリシーを作成できる
  # - 例: SQS 送信権限、DynamoDB 書き込み権限など
  # - ポリシーの内容は呼び出し元で定義（柔軟性を確保）
}

# 追加ポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "additional" {
  count = length(var.additional_policies)

  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.additional[count.index].arn
}

#-------------------------------------------------------------------------------
# X-Ray トレーシング用ポリシー（オプション）
#-------------------------------------------------------------------------------
# X-Ray でトレーシングを行うための権限
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

  # 解説:
  # - AWS 管理ポリシーを使用（推奨）
  # - X-Ray はリクエストのトレーシングとパフォーマンス分析に使用
  # - Lambda → SQS → Lambda のフローを可視化できる
}

#-------------------------------------------------------------------------------
# Lambda Function
#-------------------------------------------------------------------------------
resource "aws_lambda_function" "this" {
  # 関数の基本設定
  function_name = var.function_name
  description   = "Lambda function: ${var.function_name} (${var.environment})"

  # 実行ロール（この関数が AWS リソースにアクセスする際に使用）
  role = aws_iam_role.lambda.arn

  # コードのソース（ZIP ファイル）
  filename = data.archive_file.lambda_zip.output_path

  # コードの変更検出用ハッシュ
  # このハッシュが変わると Lambda 関数が更新される
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # ランタイムとハンドラー
  runtime = var.runtime # Python 3.12
  handler = var.handler # index.handler = index.py の handler 関数

  # リソース設定
  memory_size = var.memory_size # メモリサイズ（MB）、CPU も比例して割り当てられる
  timeout     = var.timeout     # タイムアウト（秒）、最大 900 秒

  # 同時実行数の制限
  # 下流システム（SQS、DynamoDB など）への負荷を制御
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # 環境変数
  # Lambda 関数内で process.env（Node.js）や os.environ（Python）でアクセス
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # X-Ray トレーシング設定
  tracing_config {
    # Active: Lambda が自動的にトレースデータを送信
    # PassThrough: 上流からのトレースヘッダーを引き継ぐのみ
    mode = "Active"
  }

  # タグ
  tags = merge(
    {
      Name        = var.function_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # ロググループが先に作成されるようにする
  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic
  ]

  # 解説:
  # 
  # 【Lambda の実行モデル】
  # - コールドスタート: 新しいコンテナが起動される（初期化時間が発生）
  # - ウォームスタート: 既存のコンテナが再利用される（高速）
  # - メモリを増やすと CPU も増える（比例関係）
  #
  # 【同時実行数（reserved_concurrent_executions）】
  # - この関数が同時に実行できる最大インスタンス数
  # - 制限することで、下流システムへの負荷を制御
  # - SQS からのメッセージ処理では、バッチサイズと合わせて調整が必要
  #
  # 【環境変数】
  # - 設定値を関数コードから分離できる
  # - SQS キュー URL、DynamoDB テーブル名などを渡す
  # - 機密情報は Secrets Manager や Parameter Store を使用（推奨）
  #
  # 【X-Ray トレーシング】
  # - 分散アプリケーションのリクエストフローを可視化
  # - パフォーマンスボトルネックの特定に有用
  # - サービスマップでアーキテクチャ全体を把握できる
}
