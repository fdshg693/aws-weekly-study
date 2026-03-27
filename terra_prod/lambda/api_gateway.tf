# =====================================
# API Gateway HTTP API
# =====================================

resource "aws_apigatewayv2_api" "lambda_http_api" {
  name          = "${var.environment}-${var.function_name}-http-api"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway for ${aws_lambda_function.main.function_name}"

  cors_configuration {
    allow_headers = ["content-type", "x-requested-with"]
    allow_methods = ["GET", "OPTIONS", "POST"]
    allow_origins = ["*"]
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

  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = min(var.timeout * 1000, 30000)
}

resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.lambda_http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

resource "aws_apigatewayv2_route" "post_root" {
  api_id    = aws_apigatewayv2_api.lambda_http_api.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.lambda_http_api.id
  name   = "$default"

  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = false
    throttling_burst_limit   = var.api_throttling_burst_limit
    throttling_rate_limit    = var.api_throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
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
  name              = "/aws/apigateway/${var.environment}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-api-logs"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_http_api" {
  statement_id  = "AllowExecutionFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_http_api.execution_arn}/*/*"
}