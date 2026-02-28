# ALB（Application Load Balancer）
# HTTP/HTTPSのトラフィックをECS Fargateタスクに分散する
# ALBはパブリックサブネットに配置し、インターネットからのアクセスを受け付ける

#-------------------------------------------------------------------------------
# ALBアクセスログ用S3バケット
# 不正アクセスの事後調査・監査に必要
# ALBのアクセスログにはクライアントIP、リクエストパス、レスポンスコード等が記録される
#
# 注意: ALBがログを書き込むには、リージョンごとのAWSアカウントIDからのPut権限が必要
# ap-northeast-1 の場合は 582318560864（ELBサービスアカウント）
# 参考: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
#-------------------------------------------------------------------------------

# AWSアカウントIDを取得（バケットポリシーのリソースARN構築に必要）
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.environment}-${var.project_name}-alb-logs"

  tags = {
    Name = "${var.environment}-${var.project_name}-alb-logs"
  }
}

# ALBログバケットのライフサイクルルール
# ログが無制限に蓄積されるとコストが増大するため、保持期間を設定
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90 # 90日後にログを自動削除
    }
  }
}

# ALBからのログ書き込みを許可するバケットポリシー
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::582318560864:root" # ap-northeast-1のELBアカウントID
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

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

  # アクセスログ設定
  # ALBを通過する全リクエストのログをS3に保存
  # 不正アクセスの調査やトラフィック分析に使用
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

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
