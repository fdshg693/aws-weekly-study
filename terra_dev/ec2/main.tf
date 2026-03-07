# EC2インスタンスの作成
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux_2023.id                                      # 最新のAmazon Linux 2023 AMIを使用
  instance_type          = var.instance_type                                                      # t2.micro, t3.smallなどスペックを変数で指定
  key_name               = var.key_name != "" ? var.key_name : aws_key_pair.generated[0].key_name # 既存のkey_nameか生成されたkey_nameを使用
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # ここで最終的にIAMの権限がEC2インスタンスに付与されます
  # iam_instance_profile に上で作成したプロファイルを指定することで、
  # このEC2インスタンスは ec2_role に設定された権限（SSM接続など）を使えるようになります
  # 
  # 実際の使用例:
  # - EC2内のアプリケーションから aws s3 ls を実行 → S3へのアクセス権限があれば成功
  # - Systems Managerのセッションマネージャーで接続 → SSMポリシーのおかげで可能
  # - アプリケーションからAWS SDKでDynamoDBにアクセス → 適切なポリシーがあれば可能
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name # IAMインスタンスプロファイルをアタッチ

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

  # ユーザーデータスクリプト（Ansibleの事前インストール）
  user_data = templatefile("${path.module}/user_data.sh", {
    environment = var.environment
  })

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
