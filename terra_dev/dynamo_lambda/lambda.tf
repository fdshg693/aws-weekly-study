data "archive_file" "prompt_api" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/prompt_api_lambda.zip"
}

resource "aws_cloudwatch_log_group" "prompt_api" {
  name              = "/aws/lambda/${var.project_name}-prompts-api-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-api-logs-${var.environment}"
      Component = "Observability"
      Purpose   = "Lambda logs"
    },
    var.additional_tags,
  )
}

resource "aws_lambda_function" "prompt_api" {
  function_name = "${var.project_name}-prompts-api-${var.environment}"
  role          = aws_iam_role.prompt_api_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.prompt_api.output_path
  source_code_hash = data.archive_file.prompt_api.output_base64sha256

  environment {
    variables = {
      PROMPTS_TABLE_NAME        = aws_dynamodb_table.prompts.name
      ACCESS_PATTERN_INDEX_NAME = "access_pattern_index"
      DEFAULT_PROMPT_LIST_LIMIT = tostring(var.default_prompt_list_limit)
      MAX_PROMPT_LIST_LIMIT     = tostring(var.max_prompt_list_limit)
      CORS_ALLOW_ORIGIN         = var.cors_allow_origin
    }
  }

  depends_on = [aws_cloudwatch_log_group.prompt_api]

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-api-${var.environment}"
      Component = "Lambda"
      Purpose   = "Prompt CRUD API"
    },
    var.additional_tags,
  )
}