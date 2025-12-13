# IAMロール/ポリシー
# Kendra はサービスロールを AssumeRole してインデックス作成や同期、ログ出力を行う。

data "aws_iam_policy_document" "kendra_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kendra.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# CloudWatch Logs へ出力するための最小権限（Kendra Index / Data Source で共通利用）
data "aws_iam_policy_document" "kendra_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "kendra_logs" {
  name        = "${var.kendra_index_name}-kendra-logs"
  description = "Allow Amazon Kendra to write logs to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.kendra_logs.json
}

# Index用ロール（主にログ出力用途）
resource "aws_iam_role" "kendra_index" {
  name               = "${var.kendra_index_name}-kendra-index-role"
  assume_role_policy = data.aws_iam_policy_document.kendra_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kendra_index_logs" {
  role       = aws_iam_role.kendra_index.name
  policy_arn = aws_iam_policy.kendra_logs.arn
}

# Data Source用ロール（Web Crawler は公開サイトをクロールするため、基本はログ出力権限で足りる想定）
resource "aws_iam_role" "kendra_data_source" {
  name               = "${var.kendra_index_name}-kendra-datasource-role"
  assume_role_policy = data.aws_iam_policy_document.kendra_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kendra_data_source_logs" {
  role       = aws_iam_role.kendra_data_source.name
  policy_arn = aws_iam_policy.kendra_logs.arn
}
