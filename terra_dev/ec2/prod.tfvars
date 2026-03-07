aws_region    = "ap-northeast-1"
environment   = "prod"
instance_type = "t3.small"
# key_name = "your-prod-key-pair-name"  # SSH接続する場合はコメントを外して設定
allowed_ssh_cidr        = ["10.0.0.0/8"] # 本番環境では必ずIPアドレスを制限すること
root_volume_size        = 20
allowed_web_access_cidr = ["0.0.0.0/0"] # Webアクセスを許可するCIDRブロック