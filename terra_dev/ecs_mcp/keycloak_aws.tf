# AWS 管理の Keycloak。
# 学習用として、既存の ALB 配下に /keycloak で公開し、バックエンドは ECS Fargate + RDS PostgreSQL とする。

locals {
  keycloak_container_name = "${var.project_name}-keycloak"
}

resource "aws_security_group" "keycloak_sg" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name        = "${var.environment}-${var.project_name}-keycloak-sg"
  description = "Security group for the Keycloak ECS service"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Keycloak traffic only from the ALB"
    from_port       = var.keycloak_container_port
    to_port         = var.keycloak_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow outbound traffic from Keycloak"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-sg"
  }
}

resource "aws_security_group" "keycloak_db_sg" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name        = "${var.environment}-${var.project_name}-keycloak-db-sg"
  description = "Security group for the Keycloak PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow PostgreSQL only from the Keycloak ECS service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.keycloak_sg[0].id]
  }

  egress {
    description = "Allow outbound traffic from the database security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-db-sg"
  }
}

resource "aws_db_subnet_group" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name       = "${var.environment}-${var.project_name}-keycloak-db-subnet"
  subnet_ids = [aws_subnet.private_1a.id, aws_subnet.private_1c.id]

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-db-subnet"
  }
}

resource "aws_db_instance" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  identifier                 = "${var.environment}-${var.project_name}-keycloak"
  engine                     = "postgres"
  instance_class             = var.keycloak_db_instance_class
  allocated_storage          = var.keycloak_db_allocated_storage
  max_allocated_storage      = var.keycloak_db_allocated_storage + 20
  db_name                    = var.keycloak_db_name
  username                   = var.keycloak_db_username
  password                   = var.keycloak_db_password
  port                       = 5432
  storage_encrypted          = true
  publicly_accessible        = false
  deletion_protection        = false
  skip_final_snapshot        = true
  backup_retention_period    = 0
  apply_immediately          = true
  db_subnet_group_name       = aws_db_subnet_group.keycloak[0].name
  vpc_security_group_ids     = [aws_security_group.keycloak_db_sg[0].id]
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-db"
  }
}

resource "aws_cloudwatch_log_group" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name              = "/ecs/${var.environment}-${var.project_name}-keycloak"
  retention_in_days = var.log_retention_in_days

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-log-group"
  }
}

resource "aws_lb_target_group" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name        = "${var.environment}-${var.project_name}-kc-tg"
  port        = var.keycloak_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "${var.keycloak_path}/health/ready"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-tg"
  }
}

resource "aws_lb_listener_rule" "keycloak" {
  count        = var.deploy_keycloak_on_aws ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak[0].arn
  }

  condition {
    path_pattern {
      values = ["${var.keycloak_path}*"]
    }
  }
}

resource "aws_ecs_task_definition" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  family                   = "${var.environment}-${var.project_name}-keycloak"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.keycloak_cpu
  memory                   = var.keycloak_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = local.keycloak_container_name
      image = var.keycloak_container_image

      portMappings = [
        {
          containerPort = var.keycloak_container_port
          hostPort      = var.keycloak_container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "KC_DB"
          value = "postgres"
        },
        {
          name  = "KC_DB_URL_HOST"
          value = aws_db_instance.keycloak[0].address
        },
        {
          name  = "KC_DB_URL_PORT"
          value = tostring(aws_db_instance.keycloak[0].port)
        },
        {
          name  = "KC_DB_URL_DATABASE"
          value = var.keycloak_db_name
        },
        {
          name  = "KC_DB_USERNAME"
          value = var.keycloak_db_username
        },
        {
          name  = "KC_DB_PASSWORD"
          value = var.keycloak_db_password
        },
        {
          name  = "KEYCLOAK_ADMIN"
          value = var.keycloak_admin_username
        },
        {
          name  = "KEYCLOAK_ADMIN_PASSWORD"
          value = var.keycloak_admin_password
        },
        {
          name  = "KC_HOSTNAME"
          value = "https://${local.public_hostname}"
        },
        {
          name  = "KC_HTTP_RELATIVE_PATH"
          value = var.keycloak_path
        },
        {
          name  = "KC_HTTP_ENABLED"
          value = "true"
        },
        {
          name  = "KC_PROXY_HEADERS"
          value = "xforwarded"
        },
        {
          name  = "KC_HEALTH_ENABLED"
          value = "true"
        },
        {
          name  = "KC_METRICS_ENABLED"
          value = "true"
        }
      ]

      command = ["start"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.keycloak[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.environment}-${var.project_name}-keycloak-task-definition"
  }
}

resource "aws_ecs_service" "keycloak" {
  count = var.deploy_keycloak_on_aws ? 1 : 0

  name            = "${var.environment}-${var.project_name}-keycloak-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.keycloak[0].arn
  desired_count   = var.keycloak_desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 180

  network_configuration {
    subnets          = [aws_subnet.private_1a.id, aws_subnet.private_1c.id]
    security_groups  = [aws_security_group.keycloak_sg[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak[0].arn
    container_name   = local.keycloak_container_name
    container_port   = var.keycloak_container_port
  }

  depends_on = [aws_lb_listener_rule.keycloak]
}