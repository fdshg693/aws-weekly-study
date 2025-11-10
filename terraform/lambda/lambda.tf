# =====================================
# Lambda関数のソースコードアーカイブ
# =====================================

# Lambda関数のソースコードをZIPファイルにアーカイブ
# Terraformはソースコードの変更を自動的に検出し、必要に応じて再デプロイする
data "archive_file" "lambda_zip" {
  # アーカイブタイプ（ZIP形式）
  type = "zip"
  
  # アーカイブ元のディレクトリパス
  # src/ ディレクトリ内のすべてのファイルが含まれる
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
  # Lambda関数の一意の名前
  # 環境名をプレフィックスとして付与することで環境ごとに分離
  function_name = "${var.environment}-${var.function_name}"
  
  # 関数の説明（オプション）
  description = "Simple Lambda function deployed with Terraform in ${var.environment} environment"
  
  # =====================================
  # ランタイムとハンドラーの設定
  # =====================================
  
  # 実行ランタイム（Python, Node.js, Java等）
  runtime = var.runtime
  
  # 呼び出されるハンドラー関数
  # 形式: <ファイル名>.<関数名>
  handler = var.handler
  
  # =====================================
  # デプロイパッケージの設定
  # =====================================
  
  # デプロイパッケージのZIPファイル名
  filename = data.archive_file.lambda_zip.output_path
  
  # ZIPファイルのハッシュ値
  # ソースコードが変更された場合、この値も変更され、Lambda関数が更新される
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  # 代替方法: S3からデプロイパッケージを取得
  # s3_bucket = "my-lambda-deployment-bucket"
  # s3_key    = "lambda-function-v1.0.0.zip"
  # s3_object_version = "version-id" # バージョニング有効な場合
  
  # =====================================
  # 実行ロールの設定
  # =====================================
  
  # Lambda関数が使用するIAMロールのARN
  # このロールにより、Lambda関数が他のAWSサービスにアクセスできる
  role = aws_iam_role.lambda_role.arn
  
  # =====================================
  # リソース設定
  # =====================================
  
  # メモリサイズ（MB）
  # メモリを増やすとCPUパフォーマンスも向上する
  memory_size = var.memory_size
  
  # タイムアウト時間（秒）
  # 関数の最大実行時間
  timeout = var.timeout
  
  # ストレージサイズ（/tmpディレクトリ）
  # 範囲: 512MB 〜 10,240MB
  # 一時ファイルの保存に使用
  ephemeral_storage {
    size = 512 # MB
  }
  
  # =====================================
  # 同時実行数の設定
  # =====================================
  
  # 予約済み同時実行数
  # -1: 制限なし（デフォルト）
  # 0以上: 指定された数まで同時実行を制限
  reserved_concurrent_executions = var.reserved_concurrent_executions
  
  # =====================================
  # 環境変数の設定
  # =====================================
  
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
    for_each = var.enable_vpc ? [1] : []
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
    for_each = var.enable_dlq ? [1] : []
    content {
      # SQSキューまたはSNSトピックのARN
      target_arn = var.dlq_target_arn
    }
  }
  
  # =====================================
  # トレーシング設定
  # =====================================
  
  # AWS X-Rayによる分散トレーシング
  # パフォーマンス分析とデバッグに使用
  tracing_config {
    mode = var.tracing_mode # "PassThrough" または "Active"
  }
  
  # =====================================
  # ファイルシステム設定（オプション）
  # =====================================
  
  # Amazon EFSをマウントする場合の設定
  # 大きなファイルや永続的なデータの保存に使用
  # file_system_config {
  #   arn              = aws_efs_access_point.lambda.arn
  #   local_mount_path = "/mnt/efs"
  # }
  
  # =====================================
  # イメージ設定（コンテナイメージを使用する場合）
  # =====================================
  
  # コンテナイメージからLambda関数をデプロイする場合
  # package_type = "Image"
  # image_uri    = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-lambda:latest"
  # image_config {
  #   command           = ["app.handler"]
  #   entry_point       = ["/lambda-entrypoint.sh"]
  #   working_directory = "/var/task"
  # }
  
  # =====================================
  # レイヤー設定（オプション）
  # =====================================
  
  # Lambda Layersを使用して共通ライブラリを共有
  # layers = [
  #   "arn:aws:lambda:ap-northeast-1:123456789012:layer:my-layer:1",
  #   aws_lambda_layer_version.dependencies.arn
  # ]
  
  # =====================================
  # アーキテクチャ設定
  # =====================================
  
  # 実行アーキテクチャ
  # "x86_64" (デフォルト) または "arm64" (Graviton2)
  # arm64は一般的にコストパフォーマンスが高い
  architectures = ["x86_64"]
  
  # =====================================
  # タグ設定
  # =====================================
  
  # リソースタグ
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

# =====================================
# Lambda関数の呼び出し許可（API Gateway用の例）
# =====================================

# API Gatewayに Lambda関数の呼び出し許可を与える
# resource "aws_lambda_permission" "api_gateway" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.main.function_name
#   principal     = "apigateway.amazonaws.com"
#   
#   # 特定のAPI Gatewayからのみ許可する場合
#   # source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
# }

# =====================================
# Lambda関数のエイリアス（オプション）
# =====================================

# Lambda関数のバージョン管理とトラフィックシフトに使用
# resource "aws_lambda_alias" "live" {
#   name             = "live"
#   description      = "Alias pointing to the live version"
#   function_name    = aws_lambda_function.main.function_name
#   function_version = aws_lambda_function.main.version
#   
#   # 段階的なトラフィックシフト（Blue/Green デプロイ）
#   # routing_config {
#   #   additional_version_weights = {
#   #     "2" = 0.1  # 新バージョンに10%のトラフィックを送信
#   #   }
#   # }
# }

# =====================================
# Lambda関数のバージョン公開
# =====================================

# Lambda関数のバージョンを公開（不変）
# resource "aws_lambda_function_version" "latest" {
#   function_name = aws_lambda_function.main.function_name
#   
#   # バージョンの説明
#   description = "Latest version deployed at ${timestamp()}"
#   
#   # 公開するコードのハッシュ
#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
# }

# =====================================
# イベントソースマッピング（例: SQS）
# =====================================

# SQSキューからLambda関数をトリガーする
# resource "aws_lambda_event_source_mapping" "sqs_trigger" {
#   event_source_arn = aws_sqs_queue.lambda_queue.arn
#   function_name    = aws_lambda_function.main.function_name
#   
#   # バッチサイズ（一度に処理するメッセージ数）
#   batch_size = 10
#   
#   # バッチウィンドウ（秒）
#   maximum_batching_window_in_seconds = 5
#   
#   # エラー時の動作
#   function_response_types = ["ReportBatchItemFailures"]
# }
