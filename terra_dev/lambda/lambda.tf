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
  
  # ファイル権限の除外
  # これにより、ファイルのパーミッション変更による不要な再デプロイを防ぐ
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

resource "aws_lambda_function" "main" {
  # Lambda関数の一意の名前。環境名をプレフィックスとして付与することで環境ごとに分離
  function_name = "${var.environment}-${var.function_name}"
  
  description = "Simple Lambda function deployed with Terraform in ${var.environment} environment"
  
  # 実行ランタイム（Python, Node.js, Java等）
  runtime = var.runtime
  
  # 呼び出されるハンドラー関数。形式: <ファイル名>.<関数名>
  handler = var.handler
  
  # =====================================
  # デプロイパッケージの設定
  # =====================================
  
  # デプロイパッケージのZIPファイル名
  filename = data.archive_file.lambda_zip.output_path
  
  # ZIPファイルのハッシュ値。ソースコードが変更された場合、この値も変更され、Lambda関数が更新される
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  # 代替方法: S3からデプロイパッケージを取得
  # s3_bucket = "my-lambda-deployment-bucket"
  # s3_key    = "lambda-function-v1.0.0.zip"
  # s3_object_version = "version-id" # バージョニング有効な場合
  
  # =====================================
  # 実行ロールの設定
  # =====================================
  
  # Lambda関数が使用するIAMロールのARN。このロールにより、Lambda関数が他のAWSサービスにアクセスできる
  role = aws_iam_role.lambda_role.arn
  
  # =====================================
  # リソース設定
  # =====================================
  
  # メモリサイズ（MB）。メモリを増やすとCPUパフォーマンスも向上する
  memory_size = var.memory_size
  
  # タイムアウト時間（秒）
  timeout = var.timeout
  
  # ストレージサイズ（/tmpディレクトリ）
  # 範囲: 512MB 〜 10,240MB
  # 一時ファイルの保存に使用
  ephemeral_storage {
    size = 512 # MB
  }
  
  # 予約済み同時実行数
  # -1: 制限なし（デフォルト）
  # 0以上: 指定された数まで同時実行を制限
  reserved_concurrent_executions = var.reserved_concurrent_executions
  
  # Lambda関数内で使用する環境変数
  environment {
    variables = merge(
      {
        # デフォルトの環境変数
        ENVIRONMENT = var.environment
        APP_NAME    = var.function_name
        LOG_LEVEL   = var.environment == "production" ? "INFO" : "DEBUG"
      },
      # ユーザー定義の環境変数をマージ
      var.environment_variables
    )
  }
  
  # =====================================
  # VPC設定（オプション）
  # =====================================
  
  # Lambda関数をVPC内で実行する場合の設定
  # VPC内で実行すると、プライベートリソース（RDS等）にアクセス可能
  dynamic "vpc_config" {
    count = var.enable_vpc ? 1 : 0
    content {
      # Lambda関数を配置するサブネットID
      # 複数のAZにまたがるサブネットを指定することを推奨
      subnet_ids = var.vpc_subnet_ids
      
      # セキュリティグループID
      # Lambda関数のアウトバウンド・インバウンドトラフィックを制御
      security_group_ids = var.vpc_security_group_ids
    }
  }
  
  # =====================================
  # デッドレターキュー（DLQ）の設定
  # =====================================
  
  # 非同期実行で失敗したイベントの送信先
  dynamic "dead_letter_config" {
    count = var.enable_dlq ? 1 : 0
    content {
      # SQSキューまたはSNSトピックのARN
      target_arn = var.dlq_target_arn
    }
  }
  
  # AWS X-Rayによる分散トレーシング
  tracing_config {
    mode = var.tracing_mode # "PassThrough" または "Active"
  }
  
  # "x86_64" (デフォルト) または "arm64" (Graviton2)。arm64は一般的にコストパフォーマンスが高い
  architectures = ["x86_64"]
  
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
  # これにより、ログ保持期間の設定が確実に適用される
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
  # ログ群名（Lambda関数の命名規則に従う）
  name = "/aws/lambda/${var.environment}-${var.function_name}"
  
  # ログの保持期間（日数）
  # コスト管理とコンプライアンス要件に応じて設定
  retention_in_days = var.log_retention_days
  
  # ログの暗号化（オプション）
  # KMSキーを使用してログを暗号化
  # kms_key_id = aws_kms_key.lambda_logs.arn
  
  tags = {
    Name        = "${var.environment}-${var.function_name}-logs"
    Environment = var.environment
  }
}