# BFF Lambda + API Gateway + DynamoDB Configuration
# =================================================
# BFF（Backend For Frontend）をLambda + API Gateway HTTP APIでデプロイします。
# セッションデータはDynamoDBに保存し、TTLで自動期限切れを実現します。
#
# アーキテクチャ:
# ┌──────────────┐     ┌───────────────────┐     ┌────────────┐
# │ Amplify      │────>│ API Gateway       │────>│ Lambda     │
# │ (Vue SPA)    │CORS │ HTTP API v2       │     │ (Express)  │
# └──────────────┘     └───────────────────┘     └─────┬──────┘
#                                                       │
#                                                 ┌─────┴──────┐
#                                                 │ DynamoDB   │
#                                                 │ (sessions) │
#                                                 └────────────┘
#
# 参考:
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api

# ========================================
# DynamoDB Table (セッションストア)
# ========================================
# BFFのセッションデータと認可フロー一時データを保存します。
#
# テーブル構造:
# - pk: パーティションキー（"session:<id>" または "pending:<state>"）
# - ttl: TTL属性（Unixタイムスタンプ秒。期限切れデータを自動削除）
#
# 課金モード:
# - PAY_PER_REQUEST: オンデマンド（実験用途に最適。使った分だけ課金）
# - PROVISIONED: プロビジョン済み（本番で予測可能なトラフィックがある場合）

resource "aws_dynamodb_table" "bff_sessions" {
  name         = "${var.project_name}-${var.environment}-bff-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  # TTL設定
  # DynamoDBが定期的に期限切れアイテムを自動削除します（最大48時間の遅延あり）。
  # アプリ側でもttlチェックを行い、即座に無効化しています。
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-bff-sessions"
    },
    var.additional_tags
  )
}

# ========================================
# IAM Role (Lambda実行ロール)
# ========================================
# Lambda関数に付与するIAMロールです。
# - CloudWatch Logsへのログ出力
# - DynamoDBテーブルへのCRUD操作

resource "aws_iam_role" "bff_lambda" {
  name = "${var.project_name}-${var.environment}-bff-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-bff-lambda-role"
    },
    var.additional_tags
  )
}

# CloudWatch Logs 書き込み権限
resource "aws_iam_role_policy_attachment" "bff_lambda_logs" {
  role       = aws_iam_role.bff_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB CRUD権限
# セッションの作成・読み取り・更新・削除に必要な最小限の権限のみ付与
resource "aws_iam_role_policy" "bff_lambda_dynamodb" {
  name = "dynamodb-sessions"
  role = aws_iam_role.bff_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
      ]
      Resource = aws_dynamodb_table.bff_sessions.arn
    }]
  })
}

# ========================================
# Lambda Function (BFF)
# ========================================
# serverless-http でラップしたExpressアプリをLambdaで実行します。
#
# デプロイ方式:
# 1. null_resource で npm ci --omit=dev を実行
# 2. archive_file でBFFディレクトリをzip化
# 3. Lambda関数にアップロード
#
# 環境変数でCognito設定・DynamoDBテーブル名を渡します。
# config.jsonは不要（Lambda環境では環境変数を使用）。

resource "null_resource" "bff_npm_install" {
  # package.jsonが変更された場合のみ再実行
  triggers = {
    package_json = filemd5("${path.module}/bff/package.json")
  }

  provisioner "local-exec" {
    command     = "npm ci --omit=dev"
    working_dir = "${path.module}/bff"
  }
}

data "archive_file" "bff_lambda" {
  depends_on = [null_resource.bff_npm_install]

  type        = "zip"
  source_dir  = "${path.module}/bff"
  output_path = "${path.module}/bff_lambda.zip"

  # config.jsonはローカル開発用のため除外（Lambda環境では環境変数を使用）
  excludes = ["config.json"]
}

resource "aws_lambda_function" "bff" {
  function_name = "${var.project_name}-${var.environment}-bff"
  role          = aws_iam_role.bff_lambda.arn

  # ハンドラー: lambda.js の handler エクスポート
  # ESMモジュール（"type": "module"）のため、拡張子なしで指定
  handler = "lambda.handler"
  runtime = "nodejs20.x"

  # タイムアウト: Cognito Token Endpointへの通信を考慮して30秒
  timeout     = 30
  memory_size = 256

  filename         = data.archive_file.bff_lambda.output_path
  source_code_hash = data.archive_file.bff_lambda.output_base64sha256

  environment {
    variables = {
      # セッションストア設定
      SESSION_STORE_TYPE = "dynamodb"
      SESSION_TABLE_NAME = aws_dynamodb_table.bff_sessions.name

      # Cognito設定（config.jsonの代わりに環境変数で渡す）
      COGNITO_REGION = var.aws_region
      USER_POOL_ID   = aws_cognito_user_pool.main.id
      CLIENT_ID      = aws_cognito_user_pool_client.main.id
      CLIENT_SECRET  = aws_cognito_user_pool_client.main.client_secret
      COGNITO_DOMAIN = "${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com"

      # URL設定
      # REDIRECT_URI: API GatewayのURLをベースにコールバックURLを設定
      # FRONTEND_ORIGIN: AmplifyのURLをフロントエンドオリジンとして設定
      REDIRECT_URI    = "${trimsuffix(aws_apigatewayv2_stage.bff.invoke_url, "/")}/auth/callback"
      LOGOUT_URI      = "https://main.${aws_amplify_app.frontend.default_domain}/"
      FRONTEND_ORIGIN = "https://main.${aws_amplify_app.frontend.default_domain}"

      # Node.js設定
      NODE_ENV = "production"
    }
  }

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-bff-lambda"
    },
    var.additional_tags
  )
}

# ========================================
# API Gateway HTTP API (v2)
# ========================================
# Lambda BFFをインターネットに公開するためのAPI Gatewayです。
#
# HTTP API (v2) を選択した理由:
# - REST API (v1) より低コスト・低レイテンシー
# - Cookie / Set-Cookie ヘッダーをネイティブサポート
# - CORS設定が簡単
# - 実験用途では十分な機能

resource "aws_apigatewayv2_api" "bff" {
  name          = "${var.project_name}-${var.environment}-bff-api"
  protocol_type = "HTTP"

  # CORS設定
  # フロントエンド（Amplify）からのクロスオリジンリクエストを許可します。
  # Express側のcorsミドルウェアと二重になりますが、
  # プリフライトリクエスト（OPTIONS）はAPI Gatewayレベルで処理されます。
  cors_configuration {
    allow_origins     = ["https://main.${aws_amplify_app.frontend.default_domain}"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["Content-Type", "x-csrf-token", "Cookie"]
    allow_credentials = true
    max_age           = 3600
  }

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-bff-api"
    },
    var.additional_tags
  )
}

# Lambda統合
# API Gatewayが受けたリクエストをLambda関数に転送する設定です。
# payload_format_version = "2.0" はHTTP API v2のイベント形式を使用します。
resource "aws_apigatewayv2_integration" "bff_lambda" {
  api_id             = aws_apigatewayv2_api.bff.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.bff.invoke_arn
  integration_method = "POST"

  # ペイロード形式 2.0:
  # - リクエスト: { version, routeKey, rawPath, rawQueryString, cookies, headers, ... }
  # - レスポンス: { statusCode, headers, body, cookies, isBase64Encoded }
  payload_format_version = "2.0"
}

# デフォルトルート
# 全パスをLambdaに転送します（Express routerが内部でルーティング）。
resource "aws_apigatewayv2_route" "bff_default" {
  api_id    = aws_apigatewayv2_api.bff.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.bff_lambda.id}"
}

# デフォルトステージ（自動デプロイ）
resource "aws_apigatewayv2_stage" "bff" {
  api_id      = aws_apigatewayv2_api.bff.id
  name        = "$default"
  auto_deploy = true

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-bff-api-stage"
    },
    var.additional_tags
  )
}

# Lambda実行権限
# API GatewayがLambda関数を呼び出すための権限を付与します。
resource "aws_lambda_permission" "bff_apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bff.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bff.execution_arn}/*/*"
}
