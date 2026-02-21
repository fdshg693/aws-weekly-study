# =====================================
# Lambda関数のソースコードアーカイブ
# =====================================

# Lambda関数のソースコードをZIPファイルにアーカイブ
# Terraformはソースコードの変更を自動的に検出し、必要に応じて再デプロイする
data "archive_file" "lambda_zip" {
  # アーカイブタイプ（ZIP形式）
  type = "zip"

  # アーカイブ元のディレクトリパス
  source_dir = "${path.module}/src"

  # 出力先のZIPファイルパス
  # ${path.module} は現在のTerraformモジュールのディレクトリパスを指す
  output_path = "${path.module}/lambda_function.zip"

  # 不要なファイルを除外
  excludes = [
    "__pycache__",
    "*.pyc",
    ".DS_Store",
    "*.md",
    "tests",
    ".pytest_cache"
  ]
}

# =====================================
# Lambda関数の定義
# =====================================

resource "aws_lambda_function" "api" {
  # Lambda関数の一意の名前。環境名をプレフィックスとして付与
  function_name = "${var.environment}-${var.function_name}"

  description = "DynamoDB CRUD API - ${var.environment} environment"

  # 実行ランタイム
  runtime = var.runtime

  # 呼び出されるハンドラー関数。形式: <ファイル名>.<関数名>
  handler = var.handler

  # =====================================
  # デプロイパッケージの設定
  # =====================================

  # デプロイパッケージのZIPファイル
  filename = data.archive_file.lambda_zip.output_path

  # ZIPファイルのハッシュ値
  # ソースコードが変更された場合にLambda関数が更新される
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # =====================================
  # 実行ロールの設定
  # =====================================

  # Lambda関数が使用するIAMロールのARN
  role = aws_iam_role.lambda_role.arn

  # =====================================
  # リソース設定
  # =====================================

  # メモリサイズ（MB）
  memory_size = var.memory_size

  # タイムアウト時間（秒）
  timeout = var.timeout

  # Lambda関数内で使用する環境変数
  environment {
    variables = {
      ENVIRONMENT      = var.environment
      LOG_LEVEL        = var.environment == "production" ? "INFO" : "DEBUG"
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.items.name
    }
  }

  # default_tagsと合わせて使用される
  tags = merge(
    {
      Name    = "${var.environment}-${var.function_name}"
      Runtime = var.runtime
    },
    var.tags
  )

  # =====================================
  # 依存関係の設定
  # =====================================

  # CloudWatch Logsグループが先に作成されることを保証
  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

# =====================================
# CloudWatch Logsグループ
# =====================================

# Lambda関数のログを保存するCloudWatch Logsグループ
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  # ロググループ名（Lambda関数の命名規則に従う）
  name = "/aws/lambda/${var.environment}-${var.function_name}"

  # ログの保持期間（日数）
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-logs"
    Environment = var.environment
  }
}
