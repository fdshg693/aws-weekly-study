EC2インスタンスの初期設定スクリプトには、いくつかの方法とベストプラクティスがあります。主要なアプローチを紹介します。

## 1. User Data（最も基本的な方法）

EC2起動時に一度だけ実行されるスクリプトです。

```bash
#!/bin/bash
# ログを残す
exec > >(tee /var/log/user-data.log)
exec 2>&1

# パッケージ更新
yum update -y

# 必要なパッケージインストール
yum install -y docker git

# サービス起動
systemctl start docker
systemctl enable docker

# アプリケーション設定
echo "Setup completed at $(date)" > /var/log/setup-complete.txt
```

**注意点:**
- 再起動すると実行されない
- エラーハンドリングが重要
- 実行ログを必ず残す

## 2. Cloud-Init（より高度な方法）

YAML形式で記述できる、クロスプラットフォーム対応の初期化ツールです。
特別な設定は不要です。User Dataに#cloud-configで始まるYAMLを書くだけで自動的にCloud-Initが解釈します。
ほとんどのAMIには既にインストール済みです。

```yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker
  - git
  - nginx

runcmd:
  - systemctl start docker
  - systemctl enable docker
  - echo "Setup completed" > /tmp/setup.log

write_files:
  - path: /etc/myapp/config.yml
    content: |
      environment: production
      port: 8080
    permissions: '0644'
```

**利点:**
- 宣言的で読みやすい
- モジュール化されている
- べき等性が保証されやすい

## 3. Terraform + User Data

Terraformで管理する場合の例です。

```hcl
resource "aws_instance" "web" {
  ami           = "ami-xxxxx"
  instance_type = "t3.micro"

  user_data = templatefile("${path.module}/scripts/init.sh", {
    environment = var.environment
    app_version = var.app_version
  })

  # または直接記述
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from Terraform"
              yum update -y
              EOF
}

# 外部ファイルを使う場合
resource "aws_instance" "web_with_file" {
  ami           = "ami-xxxxx"
  instance_type = "t3.micro"
  
  user_data = file("${path.module}/scripts/init.sh")
}
```

## 4. ベストプラクティス集

### エラーハンドリング

```bash
#!/bin/bash
set -e  # エラーで停止
set -u  # 未定義変数でエラー
set -o pipefail  # パイプラインのエラーを検知

# ログ設定
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "Starting setup at $(date)"

# 関数でエラーハンドリング
setup_docker() {
    if ! command -v docker &> /dev/null; then
        yum install -y docker || {
            echo "Failed to install docker"
            return 1
        }
    fi
    systemctl start docker
    systemctl enable docker
}

# メイン処理
if setup_docker; then
    echo "Docker setup successful"
else
    echo "Docker setup failed"
    exit 1
fi
```

### 冪等性を保つ

```bash
#!/bin/bash

# 既に実行済みかチェック
MARKER_FILE="/var/log/user-data-executed"
if [ -f "$MARKER_FILE" ]; then
    echo "User data already executed"
    exit 0
fi

# セットアップ処理
yum update -y

# 完了マーカーを作成
touch "$MARKER_FILE"
echo "$(date)" >> "$MARKER_FILE"
```

### パラメータストアから設定取得

```bash
#!/bin/bash

# AWS CLIで設定取得
REGION="ap-northeast-1"
DB_PASSWORD=$(aws ssm get-parameter \
    --name "/myapp/db/password" \
    --with-decryption \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text)

# 環境変数として設定
cat > /etc/environment <<EOF
DB_HOST=mydb.example.com
DB_PASSWORD=$DB_PASSWORD
EOF
```

## 5. デバッグ方法

スクリプトがうまく動かない時の確認ポイント:

```bash
# User Dataログ確認
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# 自分で設定したログ確認
sudo cat /var/log/user-data.log

# Cloud-Initのステータス確認
cloud-init status
cloud-init status --long
```

## 6. セキュリティ考慮事項

- **機密情報をハードコードしない** → Systems Manager Parameter Store / Secrets Manager使用
- **最小権限のIAMロール**を付与
- **スクリプトにパスワードを含めない**
- IMDSv2を使用してメタデータ取得

```bash
# IMDSv2でメタデータ取得
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
```

どのような用途で初期設定スクリプトを書こうとしていますか？より具体的なアドバイスができるかもしれません。