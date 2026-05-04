# =====================================
# Lambda関数のソースコードアーカイブ
# =====================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_function.zip"

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
# Secrets Manager
# =====================================

resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${var.environment}/${var.function_name}/api-key"
  description             = "Shared API key for ${var.environment}-${var.function_name} HTTP API"
  recovery_window_in_days = var.api_key_secret_recovery_window_in_days

  tags = merge(
    {
      Name = "${var.environment}-${var.function_name}-api-key"
    },
    var.tags
  )
}

# =====================================
# Lambda functions
# =====================================

resource "aws_lambda_function" "main" {
  function_name = "${var.environment}-${var.function_name}"
  description   = "Bedrock-backed API Lambda for ${var.environment} environment"
  runtime       = var.runtime
  handler       = var.handler
  filename      = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  memory_size      = var.memory_size
  timeout          = var.timeout

  ephemeral_storage {
    size = 512
  }

  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = merge(
      {
        ENVIRONMENT         = var.environment
        APP_NAME            = var.function_name
        LOG_LEVEL           = var.environment == "production" ? "INFO" : "DEBUG"
        BEDROCK_MODEL_ID    = var.bedrock_model_id
        BEDROCK_MAX_TOKENS  = tostring(var.bedrock_max_tokens)
        BEDROCK_TEMPERATURE = tostring(var.bedrock_temperature)
      },
      var.environment_variables
    )
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = var.dlq_target_arn
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }

  architectures = ["x86_64"]

  tags = merge(
    {
      Name    = "${var.environment}-${var.function_name}"
      Runtime = var.runtime
      Role    = "application"
    },
    var.tags
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.lambda_bedrock_access
  ]
}

resource "aws_lambda_function" "authorizer" {
  function_name = "${var.environment}-${var.function_name}-authorizer"
  description   = "Validates x-api-key for ${var.environment}-${var.function_name} HTTP API"
  role          = aws_iam_role.authorizer_role.arn
  runtime       = var.runtime
  handler       = "authorizer.lambda_handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = 128
  timeout     = 5

  environment {
    variables = {
      API_KEY_SECRET_ARN = aws_secretsmanager_secret.api_key.arn
      LOG_LEVEL          = var.environment == "production" ? "INFO" : "DEBUG"
    }
  }

  tags = merge(
    {
      Name = "${var.environment}-${var.function_name}-authorizer"
      Role = "authorizer"
    },
    var.tags
  )

  depends_on = [
    aws_cloudwatch_log_group.authorizer_log_group,
    aws_iam_role_policy_attachment.authorizer_logs,
    aws_iam_role_policy.authorizer_secret_read
  ]
}

resource "aws_lambda_function" "rotation" {
  function_name = "${var.environment}-${var.function_name}-api-key-rotation"
  description   = "Rotates shared API key secret for ${var.environment}-${var.function_name}"
  role          = aws_iam_role.rotation_role.arn
  runtime       = var.runtime
  handler       = "rotation_lambda.lambda_handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = 128
  timeout     = 30

  environment {
    variables = {
      API_KEY_SECRET_ARN = aws_secretsmanager_secret.api_key.arn
      API_KEY_LENGTH     = tostring(var.api_key_length)
      LOG_LEVEL          = var.environment == "production" ? "INFO" : "DEBUG"
    }
  }

  tags = merge(
    {
      Name = "${var.environment}-${var.function_name}-api-key-rotation"
      Role = "rotation"
    },
    var.tags
  )

  depends_on = [
    aws_cloudwatch_log_group.rotation_log_group,
    aws_iam_role_policy_attachment.rotation_logs,
    aws_iam_role_policy.rotation_secret_manage,
    aws_secretsmanager_secret.api_key
  ]
}

resource "aws_secretsmanager_secret_rotation" "api_key" {
  secret_id           = aws_secretsmanager_secret.api_key.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  rotate_immediately  = true

  rotation_rules {
    automatically_after_days = var.api_key_rotation_days
  }

  depends_on = [aws_lambda_permission.allow_secrets_manager_rotation]
}

# =====================================
# CloudWatch Logs groups
# =====================================

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.environment}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "authorizer_log_group" {
  name              = "/aws/lambda/${var.environment}-${var.function_name}-authorizer"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-authorizer-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "rotation_log_group" {
  name              = "/aws/lambda/${var.environment}-${var.function_name}-api-key-rotation"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.function_name}-rotation-logs"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_secrets_manager_rotation" {
  statement_id  = "AllowSecretsManagerRotation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.api_key.arn
}