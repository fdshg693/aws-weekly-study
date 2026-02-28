# セキュリティグループ
# ALB用とECSタスク用の2つのセキュリティグループを定義
# セキュリティグループ連鎖パターン: ALBのセキュリティグループをECSタスク側で参照し、
# ALBからのトラフィックのみを許可する

#-------------------------------------------------------------------------------
# ALB用セキュリティグループ
# インターネットからのHTTP(80)アクセスを許可
#-------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-${var.project_name}-alb-sg"
  description = "Security group for ALB - allows HTTP from internet"
  vpc_id      = aws_vpc.main.id

  # HTTP接続を許可（インターネットからALBへ）
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 全てのアウトバウンドトラフィックを許可
  # ALBからECSタスクへのヘルスチェック・リクエスト転送に必要
  egress {
    description = "Allow all outbound traffic"
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
# ECSタスク用セキュリティグループ
# ALBからのトラフィックのみを許可（セキュリティグループ参照パターン）
# CIDRブロックではなく、ALBのセキュリティグループIDを指定することで、
# ALB経由のトラフィックだけに制限できる
#-------------------------------------------------------------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "${var.environment}-${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks - allows traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  # ALBからのインバウンドのみ許可
  # security_groups にALBのセキュリティグループを指定 → ALBからのリクエストのみ通す
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # ALBのSGからのトラフィックのみ許可
  }

  # 全てのアウトバウンドトラフィックを許可
  # ECRからのイメージ取得、CloudWatch Logsへのログ送信に必要
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-ecs-sg"
  }
}
