# セキュリティグループ
# ALB 用と ECS タスク用を分け、ECS 側は ALB からの通信だけを許可する。

#-------------------------------------------------------------------------------
# ALB 用セキュリティグループ
# HTTP(80) は HTTPS(443) へのリダイレクト用、443 は実際の公開ポート。
#-------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-${var.project_name}-alb-sg"
  description = "Security group for internet-facing ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from allowed sources"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTPS from allowed sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # ALB は ECS タスクへの転送に加え、OIDC 利用時は IdP とも HTTPS 通信する。
  # そのため egress は全許可として分かりやすさを優先する。
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-alb-sg"
  }
}

#-------------------------------------------------------------------------------
# ECS タスク用セキュリティグループ
# コンテナは ALB 経由でしかアクセスできないようにする。
#-------------------------------------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.environment}-${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic only from the ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # タスクの外向き通信は ECR / CloudWatch Logs 等の HTTPS を想定する。
  egress {
    description = "Allow HTTPS outbound for ECR and CloudWatch Logs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-ecs-sg"
  }
}
