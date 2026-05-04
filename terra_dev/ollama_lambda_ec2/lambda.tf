# Secrets Manager
# ---------------
# The secret value is created from a Terraform variable to keep the project self-contained.
# Important learning note: because aws_secretsmanager_secret_version is managed by Terraform,
# the plaintext value will exist in Terraform state. README.md calls this out explicitly.

resource "aws_secretsmanager_secret" "shared_api_secret" {
  name                    = "${local.name_prefix}/shared-api-secret"
  description             = "Shared API key validated by the Lambda proxy before forwarding requests to Ollama"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = {
    Name = "${local.name_prefix}-shared-api-secret"
  }
}

resource "aws_secretsmanager_secret_version" "shared_api_secret" {
  secret_id     = aws_secretsmanager_secret.shared_api_secret.id
  secret_string = var.shared_api_secret
}

resource "aws_cloudwatch_log_group" "api_lambda" {
  name              = "/aws/lambda/${local.api_lambda_function_name}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${local.name_prefix}-api-lambda-logs"
  }
}

resource "aws_cloudwatch_log_group" "worker_lambda" {
  name              = "/aws/lambda/${local.worker_lambda_function_name}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${local.name_prefix}-worker-lambda-logs"
  }
}

resource "aws_lambda_function" "api" {
  function_name = local.api_lambda_function_name
  description   = "Validates x-api-key, enqueues asynchronous Ollama requests, and returns request status"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "api_lambda.lambda_handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = {
      DEFAULT_MODEL            = var.default_model
      REQUESTS_TABLE_NAME      = aws_dynamodb_table.requests.name
      REQUEST_QUEUE_URL        = aws_sqs_queue.request_queue.id
      REQUEST_QUEUE_GROUP_ID   = local.request_queue_group_id
      REQUEST_STATUS_TTL_HOURS = tostring(var.request_status_ttl_hours)
      SHARED_API_SECRET_ARN    = aws_secretsmanager_secret.shared_api_secret.arn
      SHARED_API_SECRET_NAME   = aws_secretsmanager_secret.shared_api_secret.name
    }
  }

  vpc_config {
    subnet_ids         = local.default_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda,
    aws_iam_role_policy_attachment.api_lambda_basic_execution,
    aws_iam_role_policy_attachment.api_lambda_vpc_execution,
    aws_iam_role_policy_attachment.api_lambda_secrets_read,
    aws_iam_role_policy_attachment.api_lambda_request_access,
    aws_secretsmanager_secret_version.shared_api_secret,
    aws_vpc_endpoint.secrets_manager,
    aws_vpc_endpoint.sqs,
    aws_vpc_endpoint.dynamodb
  ]

  tags = {
    Name = "${local.name_prefix}-api-lambda"
  }
}

resource "aws_lambda_function" "worker" {
  function_name = local.worker_lambda_function_name
  description   = "Processes queued Ollama requests sequentially and updates DynamoDB request status"
  role          = aws_iam_role.worker_lambda.arn
  runtime       = "python3.12"
  handler       = "worker_lambda.lambda_handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size                    = var.lambda_memory_size
  timeout                        = var.worker_lambda_timeout_seconds
  reserved_concurrent_executions = 1

  environment {
    variables = {
      DEFAULT_MODEL                  = var.default_model
      OLLAMA_BASE_URL                = "http://${aws_instance.ollama.private_ip}:${var.ollama_port}"
      OLLAMA_REQUEST_TIMEOUT_SECONDS = tostring(max(var.worker_lambda_timeout_seconds - 10, 10))
      REQUESTS_TABLE_NAME            = aws_dynamodb_table.requests.name
    }
  }

  vpc_config {
    subnet_ids         = local.default_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.worker_lambda,
    aws_iam_role_policy_attachment.worker_lambda_basic_execution,
    aws_iam_role_policy_attachment.worker_lambda_vpc_execution,
    aws_iam_role_policy_attachment.worker_lambda_request_status_access,
    aws_vpc_endpoint.dynamodb
  ]

  tags = {
    Name = "${local.name_prefix}-worker-lambda"
  }
}
