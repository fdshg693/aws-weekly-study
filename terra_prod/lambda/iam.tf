data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name                 = "${var.environment}-${var.function_name}-role"
  description          = "IAM role for ${var.environment}-${var.function_name} application Lambda"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  max_session_duration = 3600

  tags = {
    Name        = "${var.environment}-${var.function_name}-role"
    Environment = var.environment
  }
}

resource "aws_iam_role" "authorizer_role" {
  name                 = "${var.environment}-${var.function_name}-authorizer-role"
  description          = "IAM role for ${var.environment}-${var.function_name} API key authorizer Lambda"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  max_session_duration = 3600

  tags = {
    Name        = "${var.environment}-${var.function_name}-authorizer-role"
    Environment = var.environment
  }
}

resource "aws_iam_role" "rotation_role" {
  name                 = "${var.environment}-${var.function_name}-rotation-role"
  description          = "IAM role for ${var.environment}-${var.function_name} API key rotation Lambda"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  max_session_duration = 3600

  tags = {
    Name        = "${var.environment}-${var.function_name}-rotation-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "authorizer_logs" {
  role       = aws_iam_role.authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "rotation_logs" {
  role       = aws_iam_role.rotation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.enable_vpc ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count      = var.tracing_mode == "Active" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "lambda_bedrock_access" {
  name = "${var.environment}-${var.function_name}-bedrock-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeBedrockModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "authorizer_secret_read" {
  name = "${var.environment}-${var.function_name}-authorizer-secret-read"
  role = aws_iam_role.authorizer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadApiKeySecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.api_key.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "rotation_secret_manage" {
  name = "${var.environment}-${var.function_name}-rotation-secret-manage"
  role = aws_iam_role.rotation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageApiKeySecretVersions"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [aws_secretsmanager_secret.api_key.arn]
      }
    ]
  })
}
