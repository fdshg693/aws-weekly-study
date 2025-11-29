#===============================================================================
# API Gateway モジュール
#===============================================================================
# 
# このモジュールは REST API を作成し、Producer Lambda と統合します。
#
# ■ API Gateway の種類
# ---------------------------------------------------------
# | 種類        | 特徴                                    |
# |------------|----------------------------------------|
# | REST API   | フル機能、API キー、使用量プラン対応      |
# | HTTP API   | 低コスト、シンプル、高速（REST の約70%安い）|
# | WebSocket  | 双方向通信、リアルタイムアプリ向け        |
# ---------------------------------------------------------
#
# ■ 統合タイプ
# ---------------------------------------------------------
# | タイプ          | 説明                                 |
# |----------------|-------------------------------------|
# | AWS_PROXY      | Lambda プロキシ統合（リクエスト全体を渡す）|
# | AWS            | Lambda カスタム統合（マッピング必要）    |
# | HTTP_PROXY     | HTTP プロキシ統合                     |
# | HTTP           | HTTP カスタム統合                     |
# | MOCK           | モック統合（テスト用）                  |
# ---------------------------------------------------------
#
# ■ デプロイメントとステージ
# - デプロイメント: API の特定時点のスナップショット
# - ステージ: デプロイメントを公開する環境（dev, staging, prod など）
# - 各ステージには独自の設定（ログ、スロットリング等）が可能
#
#===============================================================================

#-------------------------------------------------------------------------------
# REST API の作成
#-------------------------------------------------------------------------------
# REST API はフル機能の API Gateway です。
# HTTP API より高機能ですが、コストも高くなります。
# 
# エンドポイントタイプ:
# - REGIONAL: 同じリージョンからのアクセスに最適化
# - EDGE: CloudFront を使用してグローバルに配信
# - PRIVATE: VPC 内からのみアクセス可能
#-------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "注文処理 API - ${var.environment} 環境"

  # エンドポイントタイプの設定
  # REGIONAL: リージョン内からのアクセスに最適化（CloudFront なし）
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-${var.environment}"
      Environment = var.environment
    }
  )
}

#-------------------------------------------------------------------------------
# API リソース（パス）の作成
#-------------------------------------------------------------------------------
# REST API はツリー構造でリソースを管理します。
# 
# 例: /orders, /orders/{orderId}, /orders/{orderId}/items
#
# parent_id に rest_api.root_resource_id を指定すると、
# ルートパス（/）の直下にリソースが作成されます。
#-------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # 親リソースの ID（ルートパス "/" の ID）
  parent_id = aws_api_gateway_rest_api.this.root_resource_id

  # パス部分（/orders となる）
  path_part = "orders"
}

#-------------------------------------------------------------------------------
# メソッドの作成（POST /orders）
#-------------------------------------------------------------------------------
# メソッドは HTTP メソッド（GET, POST, PUT, DELETE 等）を定義します。
#
# authorization の種類:
# - NONE: 認可なし（学習用、パブリック API）
# - AWS_IAM: IAM ポリシーによる認可
# - CUSTOM: Lambda オーソライザー
# - COGNITO_USER_POOLS: Cognito による認可
#-------------------------------------------------------------------------------
resource "aws_api_gateway_method" "post_orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id

  # HTTP メソッド
  http_method = "POST"

  # 認可タイプ（学習用なので NONE）
  # 本番環境では必ず認証・認可を設定すること！
  authorization = "NONE"
}

#-------------------------------------------------------------------------------
# Lambda 統合の設定
#-------------------------------------------------------------------------------
# API Gateway と Lambda を接続する統合設定です。
#
# ■ AWS_PROXY（Lambda プロキシ統合）の特徴
# - リクエスト全体（ヘッダー、パラメータ、ボディ）を Lambda に渡す
# - レスポンス形式は Lambda 側で制御
# - マッピングテンプレート不要
# - 最も一般的な統合方法
#
# ■ AWS（Lambda カスタム統合）の特徴
# - マッピングテンプレートでリクエスト/レスポンスを変換
# - 細かい制御が可能だが、設定が複雑
#-------------------------------------------------------------------------------
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method

  # 統合タイプ: AWS_PROXY = Lambda プロキシ統合
  integration_http_method = "POST" # Lambda は常に POST で呼び出す
  type                    = "AWS_PROXY"

  # Lambda 関数の呼び出し URI
  # invoke_arn は Lambda を呼び出すための特別な ARN
  uri = var.lambda_invoke_arn
}

#-------------------------------------------------------------------------------
# Lambda 実行権限
#-------------------------------------------------------------------------------
# API Gateway が Lambda 関数を呼び出すための権限を付与します。
# これがないと、API Gateway から Lambda を呼び出せません。
#
# source_arn でどの API/リソース/メソッドからの呼び出しを許可するか指定
# ワイルドカード（*）を使用して柔軟に設定可能
#-------------------------------------------------------------------------------
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # 許可する呼び出し元を指定
  # 形式: arn:aws:execute-api:{region}:{account}:{api_id}/{stage}/{method}/{path}
  # /*/*/* は「任意のステージ/任意のメソッド/任意のパス」を意味
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

#-------------------------------------------------------------------------------
# デプロイメント
#-------------------------------------------------------------------------------
# デプロイメントは API の特定時点のスナップショットです。
# API の設定を変更した後、デプロイメントを作成して反映させます。
#
# triggers ブロックで、どの変更時に再デプロイするか制御できます。
# redeployment の値が変わると、新しいデプロイメントが作成されます。
#-------------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # 依存するリソースが作成されてからデプロイ
  depends_on = [
    aws_api_gateway_integration.lambda,
  ]

  # API の設定が変更されたら再デプロイ
  # sha1 でハッシュを計算し、変更を検知
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_method.post_orders.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }

  # 新しいデプロイメントを作成してから古いものを削除
  lifecycle {
    create_before_destroy = true
  }
}

#-------------------------------------------------------------------------------
# ステージ
#-------------------------------------------------------------------------------
# ステージはデプロイメントを公開する環境です。
# 例: dev, staging, prod
#
# 各ステージには独自の設定が可能:
# - アクセスログ
# - スロットリング（レート制限）
# - キャッシュ
# - ステージ変数
#-------------------------------------------------------------------------------
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id

  # ステージ名（URL の一部になる）
  # 例: https://xxxx.execute-api.region.amazonaws.com/{stage_name}/orders
  stage_name = var.environment

  # アクセスログの設定
  access_log_settings {
    # ログの出力先（CloudWatch Logs グループの ARN）
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn

    # ログフォーマット（JSON 形式で詳細情報を記録）
    # 利用可能な変数: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-mapping-template-reference.html
    format = jsonencode({
      requestId          = "$context.requestId"          # リクエスト ID
      ip                 = "$context.identity.sourceIp"  # クライアント IP
      caller             = "$context.identity.caller"    # 呼び出し元
      user               = "$context.identity.user"      # ユーザー
      requestTime        = "$context.requestTime"        # リクエスト時刻
      httpMethod         = "$context.httpMethod"         # HTTP メソッド
      resourcePath       = "$context.resourcePath"       # リソースパス
      status             = "$context.status"             # HTTP ステータス
      protocol           = "$context.protocol"           # プロトコル
      responseLength     = "$context.responseLength"     # レスポンス長
      integrationStatus  = "$context.integrationStatus"  # 統合ステータス
      integrationLatency = "$context.integrationLatency" # 統合レイテンシ
    })
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-stage-${var.environment}"
      Environment = var.environment
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.api_gateway,
    aws_api_gateway_account.this,
  ]
}

#-------------------------------------------------------------------------------
# CloudWatch Logs グループ（アクセスログ用）
#-------------------------------------------------------------------------------
# API Gateway のアクセスログを保存するロググループです。
# 命名規則: API-Gateway-Execution-Logs_{api-id}/{stage-name}
# ※ 実際には任意の名前を使用可能
#-------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/aws/api-gateway/${var.project_name}-${var.environment}"

  # ログの保持期間（日数）
  # 0 = 無期限
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-logs-${var.environment}"
      Environment = var.environment
    }
  )
}

#-------------------------------------------------------------------------------
# API Gateway アカウント設定
#-------------------------------------------------------------------------------
# API Gateway がCloudWatch Logs にログを出力するための設定です。
# リージョンごとに1回だけ設定が必要です。
#
# 注意: このリソースはリージョン全体に影響するため、
# 複数のプロジェクトで競合する可能性があります。
#-------------------------------------------------------------------------------
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

#-------------------------------------------------------------------------------
# API Gateway 用 IAM ロール（CloudWatch Logs 出力用）
#-------------------------------------------------------------------------------
# API Gateway が CloudWatch Logs にログを出力するためのロールです。
#-------------------------------------------------------------------------------
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"

  # 信頼ポリシー: API Gateway がこのロールを引き受けることを許可
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"
      Environment = var.environment
    }
  )
}

#-------------------------------------------------------------------------------
# CloudWatch Logs 出力用ポリシー
#-------------------------------------------------------------------------------
# API Gateway が CloudWatch Logs にログを出力するための権限です。
# AWS 管理ポリシー AmazonAPIGatewayPushToCloudWatchLogs と同等
#-------------------------------------------------------------------------------
resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-policy-${var.environment}"
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

#-------------------------------------------------------------------------------
# メソッドレスポンス（オプション）
#-------------------------------------------------------------------------------
# Lambda プロキシ統合では通常不要ですが、
# CORS を設定する場合やドキュメント化のために設定することがあります。
#-------------------------------------------------------------------------------
resource "aws_api_gateway_method_response" "post_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = "200"

  # レスポンスヘッダーの定義（CORS 用）
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.post_orders]
}
