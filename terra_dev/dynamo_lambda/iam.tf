resource "aws_iam_role" "prompt_api_lambda" {
  name = "${var.project_name}-prompts-api-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-api-${var.environment}"
      Component = "IAM"
      Purpose   = "Lambda execution role"
    },
    var.additional_tags,
  )
}

resource "aws_iam_role_policy_attachment" "prompt_api_lambda_logs" {
  role       = aws_iam_role.prompt_api_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "prompt_api_lambda_dynamodb" {
  name = "${var.project_name}-prompts-dynamodb-${var.environment}"
  role = aws_iam_role.prompt_api_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPromptTableCrud"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
        ]
        Resource = [
          aws_dynamodb_table.prompts.arn,
          "${aws_dynamodb_table.prompts.arn}/index/access_pattern_index",
        ]
      }
    ]
  })
}