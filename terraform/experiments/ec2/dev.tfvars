aws_region    = "ap-northeast-1"
environment   = "dev"
instance_type = "t2.micro"
# key_name = "your-key-pair-name"  # SSH接続する場合はコメントを外して設定
allowed_ssh_cidr        = ["0.0.0.0/0"] # セキュリティ上、自分のIPアドレスに制限することを推奨
root_volume_size        = 8
allowed_web_access_cidr = ["0.0.0.0/0"] # Webアクセスを許可するCIDRブロック
