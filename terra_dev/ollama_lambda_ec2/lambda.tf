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

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}

resource "aws_lambda_function" "proxy" {
  function_name = local.lambda_function_name
  description   = "Validates x-api-key, reads the secret from Secrets Manager, and forwards prompts to Ollama on EC2"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = {
      DEFAULT_MODEL                  = var.default_model
      OLLAMA_BASE_URL                = "http://${aws_instance.ollama.private_ip}:${var.ollama_port}"
      OLLAMA_REQUEST_TIMEOUT_SECONDS = tostring(min(var.lambda_timeout_seconds - 4, 25))
      SHARED_API_SECRET_ARN          = aws_secretsmanager_secret.shared_api_secret.arn
      SHARED_API_SECRET_NAME         = aws_secretsmanager_secret.shared_api_secret.name
    }
  }

  vpc_config {
    subnet_ids         = local.default_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_iam_role_policy_attachment.lambda_secrets_read,
    aws_secretsmanager_secret_version.shared_api_secret,
    aws_vpc_endpoint.secrets_manager
  ]

  tags = {
    Name = "${local.name_prefix}-lambda"
  }
}
