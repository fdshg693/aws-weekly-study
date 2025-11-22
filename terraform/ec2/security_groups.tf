# セキュリティグループの作成
# EC2インスタンスなどのAWSリソースに対するネットワークトラフィックを制御する仮想ファイアウォール
# Security Groupはステートフルなファイアウォールで、インバウンド（入力）とアウトバウンド（出力）のトラフィックルールを定義します。
# ステートフルとは、許可された接続に対する応答トラフィックは自動的に許可されるという意味です。

# デフォルトの動作
# すべてのインバウンドトラフィックはデフォルトで拒否されます
# すべてのアウトバウンドトラフィックはデフォルトで許可されます
# ルールは「許可」のみを定義し、「拒否」ルールは作成できません

# ステートフルな性質
# インバウンドで許可された接続の戻りトラフィックは、アウトバウンドルールに関係なく自動的に許可されます
# 例えば、ポート80へのインバウンドを許可すれば、そのレスポンスは自動的に返せます
resource "aws_security_group" "ec2_sg" {
  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH接続を許可
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP接続を許可
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_access_cidr
  }

  # HTTPS接続を許可
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_access_cidr
  }

  # 全てのアウトバウンドトラフィックを許可
  # デフォルト通りの挙動だが、TERRAFORMでは書かれていないルールは削除されるため、明示的に記述する必要がある
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-ec2-sg"
  }
}
