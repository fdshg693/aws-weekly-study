# IAM roles and policies
# ----------------------
# このファイルで付与している権限の要点
# - EC2:
#   - EC2サービスがこのロールを引き受け可能
#   - Session Manager を使った接続・管理のみを許可
#   - SSH用の広い権限は付与しない
# - Lambda:
#   - Lambdaサービスがこのロールを引き受け可能
#   - CloudWatch Logs へのログ出力を許可
#   - VPC内で実行するための ENI 作成・管理を許可
#   - `shared_api_secret` という 1 つの Secrets Manager シークレットに対して
#     `DescribeSecret` / `GetSecretValue` の読み取りのみを許可
#   - Secrets の更新・削除や、他シークレットへのアクセスは許可しない

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.name_prefix}-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_secrets_read" {
  statement {
    sid = "ReadSharedApiSecret"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]

    resources = [aws_secretsmanager_secret.shared_api_secret.arn]
  }
}

resource "aws_iam_policy" "lambda_secrets_read" {
  name        = "${local.name_prefix}-lambda-secrets-read"
  description = "Allow the Lambda proxy function to read only the shared API secret"
  policy      = data.aws_iam_policy_document.lambda_secrets_read.json
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_read" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_secrets_read.arn
}
