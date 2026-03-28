# =====================================
# API Gateway HTTP API
# =====================================
#
# このファイルは、API Gateway HTTP API(v2) から Lambda を呼び出すための設定です。
#
# 全体像:
# 1. aws_apigatewayv2_api
#    - HTTP API 本体を作成する
#    - CORS(特にブラウザの preflight / OPTIONS) の自動応答もここで定義する
#
# 2. aws_apigatewayv2_integration
#    - API Gateway が「どこへ転送するか」を定義する
#    - この構成では Lambda へ AWS_PROXY でそのまま渡す
#
# 3. aws_apigatewayv2_route
#    - どの HTTP メソッド + パスを、どの integration に結びつけるか定義する
#    - ここでは GET / と POST / を Lambda にルーティングしている
#
# 4. aws_apigatewayv2_stage
#    - API のデプロイ先ステージ
#    - ログ出力、スロットリング、自動デプロイなどを管理する
#    - この構成では "$default" ステージ 1つだけを作っている
#    - いわゆる dev / stg / prod のように API Gateway stage を複数切る構成ではない
#
# 重要:
# - OPTIONS は route として明示定義していない
# - その代わり aws_apigatewayv2_api の cors_configuration により、
#   API Gateway 自身が preflight リクエストへ自動応答する
# - つまり OPTIONS は通常 Lambda まで到達しない
# - 環境の違いは主に API Gateway stage 名ではなく var.environment による
#   リソース名の切り分けで表現している

resource "aws_apigatewayv2_api" "lambda_http_api" {
  name          = "${var.environment}-${var.function_name}-http-api"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway for ${aws_lambda_function.main.function_name}"

  # CORS(Cross-Origin Resource Sharing) 設定
  # ブラウザから別オリジンの API を呼ぶとき、ブラウザは本リクエストの前に
  # preflight(OPTIONS) を送ることがある。
  # HTTP API(v2) では、ここを設定すると API Gateway が OPTIONS に自動応答する。
  # そのため REST API(v1) のように OPTIONS 用の Method / Integration / Response を
  # 個別に作る必要がない。
  cors_configuration {
    # ブラウザが実リクエストで送信してよいヘッダ。
    # 例: Content-Type: application/json を送る場合は content-type が必要。
    allow_headers = ["content-type", "x-requested-with"]

    # クロスオリジンで許可する HTTP メソッド。
    # OPTIONS を含めることで preflight を許可する。
    # ただし「OPTIONS を Lambda に転送する」という意味ではなく、
    # API Gateway が CORS 用レスポンスを返せるようにする意味合いが強い。
    allow_methods = ["GET", "OPTIONS", "POST"]

    # 呼び出しを許可する Origin。
    # "*" は任意のオリジンを許可する設定。
    # 学習用途では分かりやすいが、本番用途では必要に応じて絞る方が安全。
    allow_origins = ["*"]

    # ブラウザが preflight 結果をキャッシュしてよい秒数。
    # 300 秒の間は毎回 OPTIONS を打たずに済む場合がある。
    max_age       = 300
  }

  tags = merge(
    {
      Name = "${var.environment}-${var.function_name}-http-api"
    },
    var.tags
  )
}

resource "aws_apigatewayv2_integration" "lambda_proxy" {
  api_id = aws_apigatewayv2_api.lambda_http_api.id

  # AWS_PROXY は、API Gateway が受けたリクエストをほぼそのまま Lambda に渡す方式。
  # Lambda 側で event を見れば、HTTP メソッド、ヘッダ、body などを取得できる。
  # 非プロキシ統合よりシンプルで、Lambda をバックエンドにする場合の定番構成。
  integration_type       = "AWS_PROXY"

  # API Gateway から Lambda Invoke API を呼ぶ際のメソッド。
  # クライアントが GET/POST で来ても、Lambda 呼び出し自体は AWS API 的には POST。
  integration_method     = "POST"

  # どの Lambda に転送するかを示す ARN。
  integration_uri        = aws_lambda_function.main.invoke_arn

  # Lambda proxy integration で Lambda に渡されるイベント形式のバージョン。
  # 2.0 は HTTP API でよく使う新しい形式。
  # Lambda コード側では requestContext, headers, body, rawPath などの構造が
  # payload_format_version に依存するため、ここは実装理解に重要。
  payload_format_version = "2.0"

  # API Gateway がバックエンド応答を待つ最大時間(ms)。
  # HTTP API の上限 30 秒に合わせて、Lambda timeout が長くても 30 秒で打ち止め。
  timeout_milliseconds   = min(var.timeout * 1000, 30000)
}

resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.lambda_http_api.id

  # route_key は「HTTPメソッド + パス」の組み合わせ。
  # GET / に対するリクエストが来たら、下の target へ流す。
  route_key = "GET /"

  # この route がどの integration を呼ぶか指定する。
  # integrations/{id} という形式で関連づける。
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

resource "aws_apigatewayv2_route" "post_root" {
  api_id    = aws_apigatewayv2_api.lambda_http_api.id

  # POST / のルーティング定義。
  # たとえば fetch(..., { method: 'POST' }) はこの route にマッチする。
  route_key = "POST /"

  # GET / と同じ Lambda integration に流している。
  # Lambda 側では event.requestContext.http.method などを見て
  # GET と POST を分岐処理できる。
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

# NOTE:
# OPTIONS 用の aws_apigatewayv2_route は存在しない。
# それでもブラウザの preflight に応答できるのは、cors_configuration を設定しているため。
# したがって OPTIONS の挙動を追いたい場合は route ではなく、
# aws_apigatewayv2_api.lambda_http_api.cors_configuration を見るのが正しい。
#
# 逆に「OPTIONS も Lambda で独自処理したい」場合は、CORS 自動応答の設計と競合しやすいため、
# HTTP API の自動 CORS に任せるのか、別方式にするのかを設計段階で明確にする必要がある。

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.lambda_http_api.id

  # $default ステージは、ステージ名を URL パスに含めないデフォルトステージ。
  # 例: https://xxxxx.execute-api.ap-northeast-1.amazonaws.com/
  # REST API のように /prod を付けないシンプルな URL でアクセスできる。
  #
  # この Terraform では API Gateway stage はこの 1 つだけ。
  # つまり「STG 環境用に stage がもう 1 本ある」という構成ではない。
  # 環境の区別は stage 名ではなく、var.environment を含むリソース名
  # (例: ${var.environment}-${var.function_name}-http-api) によって行う設計。
  #
  # そのため、もし var.environment = "stg" で apply すれば
  # "stg-...-http-api" という別 API が作られ、その API の中に
  # やはり "$default" ステージが 1 つ存在する、という考え方になる。
  # 逆に 1 つの API の中へ dev/stg/prod の複数 stage を共存させる構成ではない。
  name   = "$default"

  # 変更時に自動デプロイ。
  # 学習・小規模構成では便利だが、厳密なリリース管理が必要なら明示デプロイも検討する。
  auto_deploy = true

  default_route_settings {
    # ルート単位の詳細メトリクス。
    # 必要なければ false でコストやノイズを抑える。
    detailed_metrics_enabled = false

    # 短時間バーストの上限。
    throttling_burst_limit   = var.api_throttling_burst_limit

    # 平均的なリクエストレート上限。
    throttling_rate_limit    = var.api_throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn

    # API Gateway アクセスログの JSON 形式。
    # Lambda ログとは別物で、「Gateway に何が来てどう返したか」を確認するのに使う。
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = merge(
    {
      Name = "${var.environment}-${var.function_name}-http-api-stage"
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  # API Gateway のアクセスログ出力先。
  name              = "/aws/apigateway/${var.environment}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-api-logs"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_http_api" {
  # API Gateway から Lambda を invoke できるようにするリソースベースポリシー。
  # これがないと route / integration が正しくても API Gateway は Lambda を呼べない。
  statement_id  = "AllowExecutionFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name

  # API Gateway サービスに許可を与える。
  principal     = "apigateway.amazonaws.com"

  # この HTTP API からの実行に限定。
  # /*/* は「任意ステージ / 任意メソッド / 任意パス」に近い広めの許可。
  source_arn    = "${aws_apigatewayv2_api.lambda_http_api.execution_arn}/*/*"
}