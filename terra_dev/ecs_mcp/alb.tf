# ALB（Application Load Balancer）
# HTTPS 終端と /mcp のパス転送を担当する。

locals {
  public_hostname = var.app_domain_name != "" ? var.app_domain_name : aws_lb.main.dns_name
}

resource "aws_lb" "main" {
  name               = "${var.environment}-${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]

  tags = {
    Name = "${var.environment}-${var.project_name}-alb"
  }
}

#-------------------------------------------------------------------------------
# ターゲットグループ
# ECS Fargate (awsvpc) では target_type = "ip" が必須。
# ヘルスチェックはアプリ本体ではなく Docker ラッパーが返す /health を使う。
#-------------------------------------------------------------------------------
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-tg"
  }
}

#-------------------------------------------------------------------------------
# HTTP リスナー
# 80番は常に HTTPS へリダイレクトする。
#-------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#-------------------------------------------------------------------------------
# HTTPS リスナー
# 証明書は外部前提になるため変数化する。
#-------------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  # 許可したいパスだけ個別のルールで転送し、それ以外は 404 にする。
  # 学習用として「ALB でどのパスを公開しているか」が分かりやすい構成。
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

#-------------------------------------------------------------------------------
# /.well-known/* パスの転送（サーバーサイド OAuth 時のみ）
# MCP 仕様で必要な OAuth メタデータエンドポイントを ECS へ到達させる。
# - /.well-known/oauth-authorization-server  (RFC 8414 / MCP 2025-03-26)
# - /.well-known/oauth-protected-resource    (RFC 9728 / MCP 2025-06-18)
#-------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "well_known" {
  count        = var.enable_server_oauth ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/.well-known/*"]
    }
  }
}

# /oauth/* パスの転送（サーバーサイド OAuth 時のみ）
# Dynamic Client Registration (DCR) エンドポイント用。
# Claude Desktop が client_id を自動取得するために POST /oauth/register を呼ぶ。
resource "aws_lb_listener_rule" "oauth" {
  count        = var.enable_server_oauth ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 41

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/oauth/*"]
    }
  }
}

# ヘルス確認用の /health は認証なしでターゲットへ転送する。
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}

# /mcp* は ECS タスクへ転送する。
# 認証自体はアプリケーション側（server-side OAuth）で実施する。
resource "aws_lb_listener_rule" "mcp" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["${var.mcp_path}*"]
    }
  }
}

#-------------------------------------------------------------------------------
# Route53 Alias レコード（任意）
# ACM の証明書名と一致する独自ドメインを使う場合に便利。
#-------------------------------------------------------------------------------
resource "aws_route53_record" "app" {
  count = var.create_route53_record && var.app_domain_name != "" && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
