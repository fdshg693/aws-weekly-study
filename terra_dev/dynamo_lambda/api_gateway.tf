resource "aws_api_gateway_rest_api" "prompts" {
  name        = "${var.project_name}-prompts-api-${var.environment}"
  description = "Prompt CRUD API backed by Lambda and DynamoDB"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-api-${var.environment}"
      Component = "API"
      Purpose   = "Prompt CRUD API"
    },
    var.additional_tags,
  )
}

resource "aws_api_gateway_resource" "prompts_collection" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  parent_id   = aws_api_gateway_rest_api.prompts.root_resource_id
  path_part   = "prompts"
}

resource "aws_api_gateway_resource" "prompt_item" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  parent_id   = aws_api_gateway_resource.prompts_collection.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "prompts_get" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompts_collection.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompts_get" {
  rest_api_id             = aws_api_gateway_rest_api.prompts.id
  resource_id             = aws_api_gateway_resource.prompts_collection.id
  http_method             = aws_api_gateway_method.prompts_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.prompt_api.invoke_arn
}

resource "aws_api_gateway_method" "prompts_post" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompts_collection.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompts_post" {
  rest_api_id             = aws_api_gateway_rest_api.prompts.id
  resource_id             = aws_api_gateway_resource.prompts_collection.id
  http_method             = aws_api_gateway_method.prompts_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.prompt_api.invoke_arn
}

resource "aws_api_gateway_method" "prompt_item_get" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompt_item.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompt_item_get" {
  rest_api_id             = aws_api_gateway_rest_api.prompts.id
  resource_id             = aws_api_gateway_resource.prompt_item.id
  http_method             = aws_api_gateway_method.prompt_item_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.prompt_api.invoke_arn
}

resource "aws_api_gateway_method" "prompt_item_put" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompt_item.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompt_item_put" {
  rest_api_id             = aws_api_gateway_rest_api.prompts.id
  resource_id             = aws_api_gateway_resource.prompt_item.id
  http_method             = aws_api_gateway_method.prompt_item_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.prompt_api.invoke_arn
}

resource "aws_api_gateway_method" "prompt_item_delete" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompt_item.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompt_item_delete" {
  rest_api_id             = aws_api_gateway_rest_api.prompts.id
  resource_id             = aws_api_gateway_resource.prompt_item.id
  http_method             = aws_api_gateway_method.prompt_item_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.prompt_api.invoke_arn
}

resource "aws_api_gateway_method" "prompts_options" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompts_collection.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompts_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompts_collection.id
  http_method = aws_api_gateway_method.prompts_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "prompts_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompts_collection.id
  http_method = aws_api_gateway_method.prompts_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "prompts_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompts_collection.id
  http_method = aws_api_gateway_method.prompts_options.http_method
  status_code = aws_api_gateway_method_response.prompts_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
  }
}

resource "aws_api_gateway_method" "prompt_item_options" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  resource_id   = aws_api_gateway_resource.prompt_item.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prompt_item_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompt_item.id
  http_method = aws_api_gateway_method.prompt_item_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "prompt_item_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompt_item.id
  http_method = aws_api_gateway_method.prompt_item_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "prompt_item_options" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id
  resource_id = aws_api_gateway_resource.prompt_item.id
  http_method = aws_api_gateway_method.prompt_item_options.http_method
  status_code = aws_api_gateway_method_response.prompt_item_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
  }
}

resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE'"
  }
}

resource "aws_api_gateway_deployment" "prompts" {
  rest_api_id = aws_api_gateway_rest_api.prompts.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.prompts_get.id,
      aws_api_gateway_integration.prompts_post.id,
      aws_api_gateway_integration.prompt_item_get.id,
      aws_api_gateway_integration.prompt_item_put.id,
      aws_api_gateway_integration.prompt_item_delete.id,
      aws_api_gateway_integration.prompts_options.id,
      aws_api_gateway_integration.prompt_item_options.id,
      aws_api_gateway_gateway_response.default_4xx.id,
      aws_api_gateway_gateway_response.default_5xx.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.prompts_get,
    aws_api_gateway_integration.prompts_post,
    aws_api_gateway_integration.prompt_item_get,
    aws_api_gateway_integration.prompt_item_put,
    aws_api_gateway_integration.prompt_item_delete,
    aws_api_gateway_integration_response.prompts_options,
    aws_api_gateway_integration_response.prompt_item_options,
  ]
}

resource "aws_api_gateway_stage" "prompts" {
  rest_api_id   = aws_api_gateway_rest_api.prompts.id
  deployment_id = aws_api_gateway_deployment.prompts.id
  stage_name    = var.environment

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-api-stage-${var.environment}"
      Component = "API"
      Purpose   = "Prompt CRUD stage"
    },
    var.additional_tags,
  )
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prompt_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.prompts.execution_arn}/*/*"
}