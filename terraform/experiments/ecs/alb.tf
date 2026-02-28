# ALB（Application Load Balancer）
# HTTP/HTTPSのトラフィックをECS Fargateタスクに分散する
# ALBはパブリックサブネットに配置し、インターネットからのアクセスを受け付ける

#-------------------------------------------------------------------------------
# ALB本体
# 最低2つのAZにまたがるサブネットが必要（高可用性のため）
#-------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.environment}-${var.project_name}-alb"
  internal           = false         # false = インターネット向け（パブリック）、true = 内部向け
  load_balancer_type = "application" # application: HTTP/HTTPS用、network: TCP/UDP用
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1c.id] # 2つのAZに分散配置

  tags = {
    Name = "${var.environment}-${var.project_name}-alb"
  }
}

#-------------------------------------------------------------------------------
# ターゲットグループ
# ALBがリクエストを転送する先のグループ
# Fargateの場合、target_type = "ip" にする必要がある（awsvpcネットワークモードのため）
#
# EC2の場合は target_type = "instance" だが、Fargateはインスタンスを持たないため
# タスクのENI（Elastic Network Interface）のIPアドレスを直接ターゲットにする
#-------------------------------------------------------------------------------
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate必須: タスクのIPアドレスを直接ターゲットにする

  # ヘルスチェック設定
  # ALBが定期的にターゲットの健全性を確認する
  # ヘルスチェックに失敗するとターゲットは「unhealthy」となり、リクエストが転送されなくなる
  # ECSサービスはunhealthyなタスクを停止し、新しいタスクを起動する
  health_check {
    enabled             = true
    path                = "/" # ヘルスチェック用のパス（Nginxのデフォルトページ）
    protocol            = "HTTP"
    port                = "traffic-port" # ターゲットグループに設定されたポートを使用
    healthy_threshold   = 3              # healthy判定に必要な連続成功回数
    unhealthy_threshold = 3              # unhealthy判定に必要な連続失敗回数
    timeout             = 5              # レスポンスのタイムアウト（秒）
    interval            = 30             # ヘルスチェックの間隔（秒）
    matcher             = "200"          # 成功とみなすHTTPステータスコード
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-tg"
  }
}

#-------------------------------------------------------------------------------
# リスナー
# ALBがどのポートで受け付け、どのターゲットグループに転送するかを定義
#-------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # デフォルトアクション: 全てのリクエストをターゲットグループにフォワード
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
