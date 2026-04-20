# =====================================
# API Gateway REST API
# =====================================

# REST APIの作成
# API Gatewayはクライアントからのリクエストを受け付け、Lambda関数にプロキシする
resource "aws_api_gateway_rest_api" "items_api" {
  name        = "${var.project_name}-${var.environment}"
  description = "CRUD API for items - ${var.environment}"

  # エンドポイントタイプ
  # REGIONAL: リージョナル（同一リージョン内からのアクセスに最適）
  # EDGE: エッジ最適化（CloudFront経由、グローバルアクセスに最適）
  # PRIVATE: プライベート（VPC内からのアクセスのみ）
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    {
      Name = "${var.project_name}-api-${var.environment}"
    },
    var.tags
  )
}

# =====================================
# リソース定義: /items
# =====================================

# /items リソースの作成
# REST APIのルートリソース（/）の子リソースとして /items を定義
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  parent_id   = aws_api_gateway_rest_api.items_api.root_resource_id
  path_part   = "items"
}

# /items/{id} リソースの作成
# /items の子リソースとして /{id} を定義（パスパラメータ）
resource "aws_api_gateway_resource" "item_id" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}" # パスパラメータ（pathParametersとしてLambdaに渡される）
}

# =====================================
# /items に対するHTTPメソッド
# =====================================

# GET /items - アイテム一覧取得
resource "aws_api_gateway_method" "get_items" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE" # 認証なし（学習用のためシンプルに保つ）
}

# POST /items - アイテム作成
resource "aws_api_gateway_method" "post_items" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

# =====================================
# /items/{id} に対するHTTPメソッド
# =====================================

# GET /items/{id} - アイテム個別取得
resource "aws_api_gateway_method" "get_item" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.item_id.id
  http_method   = "GET"
  authorization = "NONE"
}

# PUT /items/{id} - アイテム更新
resource "aws_api_gateway_method" "put_item" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.item_id.id
  http_method   = "PUT"
  authorization = "NONE"
}

# DELETE /items/{id} - アイテム削除
resource "aws_api_gateway_method" "delete_item" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.item_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# =====================================
# Lambda統合（/items）
# =====================================

# GET /items → Lambda プロキシ統合
resource "aws_api_gateway_integration" "get_items" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.get_items.http_method

  # AWS_PROXY: Lambdaプロキシ統合
  # リクエスト全体がそのままLambda関数に渡される
  # レスポンスもLambda関数の戻り値がそのまま返される
  type                    = "AWS_PROXY"
  integration_http_method = "POST" # Lambda呼び出しは常にPOST
  uri                     = aws_lambda_function.api.invoke_arn
}

# POST /items → Lambda プロキシ統合
resource "aws_api_gateway_integration" "post_items" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.post_items.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

# =====================================
# Lambda統合（/items/{id}）
# =====================================

# GET /items/{id} → Lambda プロキシ統合
resource "aws_api_gateway_integration" "get_item" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.item_id.id
  http_method             = aws_api_gateway_method.get_item.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

# PUT /items/{id} → Lambda プロキシ統合
resource "aws_api_gateway_integration" "put_item" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.item_id.id
  http_method             = aws_api_gateway_method.put_item.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

# DELETE /items/{id} → Lambda プロキシ統合
resource "aws_api_gateway_integration" "delete_item" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.item_id.id
  http_method             = aws_api_gateway_method.delete_item.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api.invoke_arn
}

# =====================================
# API Gatewayデプロイメント
# =====================================

# API Gatewayのデプロイ
# リソースやメソッドの変更を反映するには再デプロイが必要
resource "aws_api_gateway_deployment" "items_api" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id

  # メソッドや統合の変更時に再デプロイをトリガーするため、
  # 関連リソースの変更を検出する
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items,
      aws_api_gateway_resource.item_id,
      aws_api_gateway_method.get_items,
      aws_api_gateway_method.post_items,
      aws_api_gateway_method.get_item,
      aws_api_gateway_method.put_item,
      aws_api_gateway_method.delete_item,
      aws_api_gateway_integration.get_items,
      aws_api_gateway_integration.post_items,
      aws_api_gateway_integration.get_item,
      aws_api_gateway_integration.put_item,
      aws_api_gateway_integration.delete_item,
    ]))
  }

  # デプロイメントの再作成時に既存のデプロイメントを保持
  lifecycle {
    create_before_destroy = true
  }
}

# =====================================
# API Gatewayステージ
# =====================================

# APIのステージ（dev / prod 等）
# ステージはデプロイメントのスナップショットに名前を付けたもの
resource "aws_api_gateway_stage" "items_api" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  deployment_id = aws_api_gateway_deployment.items_api.id
  stage_name    = var.api_stage_name

  tags = merge(
    {
      Name = "${var.project_name}-${var.api_stage_name}"
    },
    var.tags
  )
}

# =====================================
# Lambda関数のInvoke権限
# =====================================

# API GatewayがLambda関数を呼び出すための権限
# リソースベースポリシーとして Lambda 関数に付与する
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  # 特定のAPI Gateway ARNからの呼び出しのみ許可
  # /*/* は任意のHTTPメソッド・リソースパスを意味する
  source_arn = "${aws_api_gateway_rest_api.items_api.execution_arn}/*/*"
}
