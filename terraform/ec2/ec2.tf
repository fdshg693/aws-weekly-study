# 最新のAmazon Linux 2023 AMIを取得
# AMIとは、Amazon Machine Imageの略で、EC2インスタンスのOSイメージのこと
# dataブロックは実行のたびに最新の情報を取得する
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  # AMIフィルタリング条件　複数を指定するとAND条件で絞り込み

  # 名前に"al2023-ami-*-x86_64"を含むものを対象
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  # 仮想化タイプが"hvm"のものを対象
  # hvmとは、ハードウェア仮想化を利用したAMIのこと
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# デフォルトVPCを取得
# AWSアカウントを作成したときに各リージョンに自動的に作成される、事前設定済みのVPC(Virtual Private Cloud)
# CIDR範囲: 172.31.0.0/16 が割り当てられる
# サブネット: 各アベイラビリティゾーン(AZ)に自動的にパブリックサブネットが作成される
# 本番環境では非推奨: セキュリティ上の理由から、本番環境では専用のカスタムVPCを作成することが推奨されます

# 既に存在するリソースを参照するため、resourceではなくdataを使用
data "aws_vpc" "default" {
  default = true
}

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

# EC2インスタンス用のIAMロール
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# SSM接続用のポリシーをアタッチ（Session Managerで接続可能にする）
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAMインスタンスプロファイルの作成
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# SSH公開鍵からKey Pairを作成（key_nameが指定されていない場合）
resource "aws_key_pair" "generated" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "${var.environment}-ec2-key"
  public_key = file(pathexpand(var.public_key_path)) # pathexpandによって、~をホームディレクトリに展開

  tags = {
    Name = "${var.environment}-ec2-key"
  }
}

# EC2インスタンスの作成
resource "aws_instance" "main" {  
  ami                    = data.aws_ami.amazon_linux_2023.id # 最新のAmazon Linux 2023 AMIを使用
  instance_type          = var.instance_type # t2.micro, t3.smallなどスペックを変数で指定
  key_name               = var.key_name != "" ? var.key_name : aws_key_pair.generated[0].key_name # 既存のkey_nameか生成されたkey_nameを使用
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name # IAMインスタンスプロファイルをアタッチ

  # root_block_device は、EC2インスタンスのルートボリューム（OSがインストールされているディスク）の設定を行うブロックです。
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3" # gp3: 汎用SSD（最新、コスパ良い）gp2: 汎用SSD（旧世代）io1/io2: プロビジョンドIOPS SSD（高性能）st1: スループット最適化HDD sc1: コールドHDD
    delete_on_termination = true # インスタンス終了時にボリュームも削除
    encrypted             = true # ボリュームを暗号化

    tags = {
      Name = "${var.environment}-ec2-root-volume"
    }
  }

  # ユーザーデータスクリプト（起動時に実行される）
  user_data = <<-EOF
              #!/bin/bash
              # システムアップデート
              dnf update -y
              
              # Nginxのインストール
              dnf install -y nginx
              
              # Nginxの起動と自動起動設定
              systemctl start nginx
              systemctl enable nginx
              
              # シンプルなHTMLページの作成
              cat > /usr/share/nginx/html/index.html <<'HTML'
              <!DOCTYPE html>
              <html>
              <head>
                  <title>EC2 Instance</title>
                  <style>
                      body { font-family: Arial, sans-serif; margin: 40px; }
                      h1 { color: #232f3e; }
                  </style>
              </head>
              <body>
                  <h1>Welcome to EC2 Instance</h1>
                  <p>Environment: ${var.environment}</p>
                  <p>This instance is managed by Terraform</p>
              </body>
              </html>
              HTML
              
              # Nginxのリロード
              systemctl reload nginx
              EOF

  tags = {
    Name = "${var.environment}-ec2-instance"
  }
}

# Elastic IPの作成（オプション）
resource "aws_eip" "main" {
  domain   = "vpc"
  instance = aws_instance.main.id

  tags = {
    Name = "${var.environment}-ec2-eip"
  }
}
