# ECS（Elastic Container Service）
# Docker 化した FastMCP サーバーを Fargate で常時稼働させる。

locals {
  container_name  = "${var.project_name}-container"
  effective_image = var.container_image != "" ? var.container_image : "${aws_ecr_repository.main.repository_url}:${var.image_tag}"
}

#-------------------------------------------------------------------------------
# ECS クラスター
# Container Insights を有効にして、CPU / メモリ / ネットワークの可視化をしやすくする。
#-------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-cluster"
  }
}

#-------------------------------------------------------------------------------
# CloudWatch Logs
# コンテナの stdout / stderr を保存する。
#-------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.environment}-${var.project_name}"
  retention_in_days = var.log_retention_in_days

  tags = {
    Name = "${var.environment}-${var.project_name}-log-group"
  }
}

#-------------------------------------------------------------------------------
# タスク定義
# ここで Docker イメージ、ポート、環境変数、ログ出力、ヘルスチェックを定義する。
#-------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.environment}-${var.project_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = local.container_name
      image = local.effective_image

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          {
            name  = "HOST"
            value = "0.0.0.0"
          },
          {
            name  = "PORT"
            value = tostring(var.container_port)
          },
          {
            name  = "PUBLIC_BASE_URL"
            value = "https://${local.public_hostname}"
          },
          {
            name  = "MCP_PATH"
            value = var.mcp_path
          },
          {
            name  = "MCP_STATELESS_HTTP"
            value = "true"
          }
        ],
        # サーバーサイド OAuth 有効時に追加する環境変数。
        # Keycloak introspection を使って毎リクエスト認証する。
        var.enable_server_oauth ? [
          {
            name  = "OAUTH_ISSUER"
            value = local.resolved_oidc_issuer
          },
          {
            name  = "OAUTH_AUTHORIZATION_ENDPOINT"
            value = local.resolved_oidc_authorization_endpoint
          },
          {
            name  = "OAUTH_TOKEN_ENDPOINT"
            value = local.resolved_oidc_token_endpoint
          },
          {
            name  = "OAUTH_REGISTRATION_ENDPOINT"
            value = local.resolved_oidc_registration_endpoint
          },
          {
            name  = "OAUTH_PUBLIC_CLIENT_ID"
            value = var.keycloak_public_client_id
          },
          {
            name  = "OAUTH_INTROSPECTION_ENDPOINT"
            value = local.resolved_oidc_introspection_endpoint
          },
          {
            name  = "OAUTH_INTROSPECTION_CLIENT_ID"
            value = var.keycloak_introspection_client_id
          },
          {
            name  = "OAUTH_INTROSPECTION_CLIENT_SECRET"
            value = var.keycloak_introspection_client_secret
          },
          {
            name  = "OAUTH_SUPPORTED_SCOPES"
            value = join(" ", local.resolved_oidc_scopes)
          },
          {
            name  = "OAUTH_REQUIRED_SCOPES"
            value = join(" ", var.oauth_required_scopes)
          },
          {
            name  = "OAUTH_EXPECTED_AUDIENCES"
            value = jsonencode(local.resolved_expected_audiences)
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # ECS タスク自身のヘルスチェック。
      # Docker ラッパーが返す /health を見るので、main.py を触らずに運用確認できる。
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import sys,urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health').status == 200 else 1)\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.environment}-${var.project_name}-task-definition"
  }
}

#-------------------------------------------------------------------------------
# ECS サービス
# desired_count を 0 にしておけば、初回 apply 時に ECR へイメージをまだ push していなくても
# インフラ側の土台を先に作れる。
#-------------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name            = "${var.environment}-${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.private_1a.id, aws_subnet.private_1c.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.https]
}
