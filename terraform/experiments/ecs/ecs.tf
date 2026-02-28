# ECS（Elastic Container Service）
# コンテナのオーケストレーションサービス
# Fargateを使うことで、EC2インスタンスの管理不要でコンテナを実行できる

#-------------------------------------------------------------------------------
# ECSクラスター
# タスクやサービスを論理的にグループ化するコンテナ
# クラスター自体にはコンピューティングリソースはない（Fargateの場合）
#-------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.project_name}-cluster"

  # Container Insights を有効化
  # コンテナレベルのメトリクス（CPU、メモリ、ネットワーク）をCloudWatchで確認できる
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-cluster"
  }
}

#-------------------------------------------------------------------------------
# CloudWatch Logsグループ
# コンテナの標準出力・標準エラー出力を収集する
# コンテナはステートレスなので、ログを外部に保存しないと消えてしまう
#-------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.environment}-${var.project_name}"
  retention_in_days = 30 # ログの保持期間（日数）。コスト削減のため適切な期間を設定

  tags = {
    Name = "${var.environment}-${var.project_name}-log-group"
  }
}

#-------------------------------------------------------------------------------
# タスク定義
# コンテナの「設計図」。どのイメージを使い、どれだけのリソースを割り当て、
# どのポートを公開するかなどを定義する
#
# Fargate固有の設定:
# - requires_compatibilities: ["FARGATE"]
# - network_mode: "awsvpc"（Fargateでは必須、各タスクにENIが割り当てられる）
# - cpu / memory: タスクレベルで指定（Fargateではコンテナレベルではなくタスクレベルで管理）
#-------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.environment}-${var.project_name}" # タスク定義のファミリー名（バージョン管理の単位）
  requires_compatibilities = ["FARGATE"]                              # Fargate起動タイプを指定
  network_mode             = "awsvpc"                                 # Fargate必須: 各タスクに専用のENIが割り当てられる
  cpu                      = var.container_cpu                        # タスクレベルのCPU（単位: CPUユニット）
  memory                   = var.container_memory                     # タスクレベルのメモリ（単位: MiB）
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # タスク実行ロール（ECRイメージ取得、ログ送信用）

  # コンテナ定義（JSON形式）
  # 1つのタスク定義に複数のコンテナを含めることも可能（サイドカーパターン）
  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-container"
      image = var.container_image != "" ? var.container_image : "${aws_ecr_repository.main.repository_url}:latest"

      # ポートマッピング
      # awsvpcモードでは hostPort = containerPort にする必要がある
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # ログ設定
      # awslogsドライバーを使用して、コンテナの出力をCloudWatch Logsに送信
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs" # ログストリームのプレフィックス（ecs/コンテナ名/タスクID）
        }
      }

      # コンテナが異常終了した場合に必須コンテナとしてタスク全体を停止させる
      essential = true
    }
  ])

  tags = {
    Name = "${var.environment}-${var.project_name}-task-definition"
  }
}

#-------------------------------------------------------------------------------
# ECSサービス
# タスクの長期実行を管理するコンポーネント
# 指定した数のタスクを常に維持し、異常終了時は自動的に新しいタスクを起動する
# ALBと連携して、タスクをターゲットグループに自動登録する
#-------------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name            = "${var.environment}-${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count # 希望するタスク数（dev: 1、prod: 2）
  launch_type     = "FARGATE"         # Fargate起動タイプ（EC2起動タイプと選択可能）

  # ネットワーク設定
  # Fargateタスクはawsvpcモードのため、サブネットとセキュリティグループを指定する
  network_configuration {
    subnets          = [aws_subnet.private_1a.id, aws_subnet.private_1c.id] # プライベートサブネットに配置
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false # プライベートサブネットなのでパブリックIPは不要（NAT Gateway経由で外部通信）
  }

  # ALBとの連携設定
  # ECSサービスが自動的にタスクのIPアドレスをターゲットグループに登録・解除する
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.project_name}-container" # タスク定義内のコンテナ名と一致させる
    container_port   = var.container_port
  }

  # ALBのリスナーが作成された後にサービスを作成する
  depends_on = [aws_lb_listener.http]
}
