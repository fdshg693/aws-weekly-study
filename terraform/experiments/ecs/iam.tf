# ECSタスク実行ロール
# ECSエージェントがタスクを起動する際に使用するIAMロール
# コンテナ自体の権限ではなく、ECSの「インフラ側」の権限を定義する
#
# 主な用途:
# - ECRからDockerイメージを取得（pull）
# - CloudWatch Logsにコンテナログを送信
# - Secrets ManagerやParameter Storeからシークレットを取得（必要に応じて）
#
# 注意: タスク実行ロール（execution role）とタスクロール（task role）は別物
# - タスク実行ロール: ECSエージェントが使う（イメージ取得、ログ送信など）
# - タスクロール: コンテナ内のアプリケーションが使う（S3アクセス、DynamoDBアクセスなど）
# 今回はタスクロールは不要（コンテナ内からAWSサービスにアクセスしないため）

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment}-${var.project_name}-ecs-execution-role"

  # ECSサービス（ecs-tasks.amazonaws.com）がこのロールを引き受けられるよう設定
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.project_name}-ecs-execution-role"
  }
}

# AmazonECSTaskExecutionRolePolicy をアタッチ
# AWSが事前に用意したマネージドポリシーで、以下の権限が含まれる:
# - ecr:GetAuthorizationToken（ECRへの認証）
# - ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, ecr:BatchGetImage（イメージ取得）
# - logs:CreateLogStream, logs:PutLogEvents（CloudWatch Logsへの書き込み）
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
