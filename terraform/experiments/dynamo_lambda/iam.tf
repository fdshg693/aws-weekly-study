# =====================================
# Lambda実行ロール
# =====================================

# Lambda関数が使用するIAMロール
# このロールにより、Lambda関数がDynamoDBやCloudWatch Logsと対話できる
resource "aws_iam_role" "lambda_role" {
  # ロール名（環境名を含めて環境ごとに分離）
  name = "${var.environment}-${var.function_name}-role"

  description = "IAM role for ${var.environment}-${var.function_name} Lambda function"

  # 信頼ポリシー（誰がこのロールを引き受けられるか）
  # Lambdaサービスにこのロールの引き受けを許可
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.function_name}-role"
    Environment = var.environment
  }
}

# =====================================
# CloudWatch Logsへの書き込み権限
# =====================================

# Lambda関数がCloudWatch Logsにログを書き込むための権限
# AWSマネージドポリシーを使用（logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents）
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =====================================
# DynamoDB操作用カスタムポリシー
# =====================================

# Lambda関数がDynamoDBテーブルに対してCRUD操作を行うための権限
# 最小権限の原則に基づき、必要な操作と対象リソースのみに限定
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.environment}-${var.function_name}-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # 個別アイテムの取得
          "dynamodb:GetItem",
          # アイテムの作成・上書き
          "dynamodb:PutItem",
          # アイテムの部分更新
          "dynamodb:UpdateItem",
          # アイテムの削除
          "dynamodb:DeleteItem",
          # テーブル全体のスキャン（一覧取得用）
          "dynamodb:Scan"
        ]
        # 対象リソースをこのプロジェクトのテーブルARNに限定
        Resource = [
          aws_dynamodb_table.items.arn
        ]
      }
    ]
  })
}
