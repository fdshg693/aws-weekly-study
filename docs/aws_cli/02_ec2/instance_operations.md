# EC2 インスタンス操作

## 目次
- [インスタンスの起動](#インスタンスの起動)
- [インスタンスの状態管理](#インスタンスの状態管理)
- [インスタンスの終了](#インスタンスの終了)
- [インスタンスの状態確認](#インスタンスの状態確認)
- [インスタンス属性の変更](#インスタンス属性の変更)
- [実践的なシナリオ](#実践的なシナリオ)

---

## インスタンスの起動

### 基本的なインスタンス起動
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0
```

### タグ付きインスタンスの起動
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=WebServer},{Key=Environment,Value=Production},{Key=Owner,Value=DevOps}]'
```

### ユーザーデータを使用したインスタンス起動
```bash
# インラインでユーザーデータを指定
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --user-data '#!/bin/bash
echo "Hello World" > /tmp/hello.txt
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd'
```

### ファイルからユーザーデータを読み込む
```bash
# user-data.sh ファイルを作成
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd git
systemctl start httpd
systemctl enable httpd
echo "<h1>Welcome to $(hostname -f)</h1>" > /var/www/html/index.html
EOF

# ファイルを指定してインスタンスを起動
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --user-data file://user-data.sh
```

### 複数のセキュリティグループを使用
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 sg-0987654321fedcba0 \
  --subnet-id subnet-0123456789abcdef0
```

### EBS ボリュームオプション付きで起動
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 20,
        "VolumeType": "gp3",
        "Iops": 3000,
        "Throughput": 125,
        "DeleteOnTermination": true,
        "Encrypted": true
      }
    },
    {
      "DeviceName": "/dev/sdf",
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "DeleteOnTermination": false
      }
    }
  ]'
```

### IAM ロールを使用してインスタンスを起動
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --iam-instance-profile Name=EC2-S3-Access-Role
```

### パブリック IP を自動割り当て
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --associate-public-ip-address
```

### プライベート IP アドレスを指定
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --private-ip-address 10.0.1.10
```

### 複数インスタンスの同時起動
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --count 3 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=WebServer},{Key=Batch,Value=2024-01}]'
```

### テナンシーオプション付きで起動
```bash
# 専有インスタンス
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --placement Tenancy=dedicated
```

### 詳細モニタリングを有効化
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --monitoring Enabled=true
```

### メタデータオプションを設定
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=1,HttpEndpoint=enabled"
```

### 起動テンプレートを使用
```bash
# 起動テンプレートの最新バージョンを使用
aws ec2 run-instances \
  --launch-template LaunchTemplateName=MyLaunchTemplate

# 特定のバージョンを指定
aws ec2 run-instances \
  --launch-template LaunchTemplateName=MyLaunchTemplate,Version=2

# 起動テンプレートをオーバーライド
aws ec2 run-instances \
  --launch-template LaunchTemplateName=MyLaunchTemplate \
  --instance-type t2.small \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Environment,Value=Development}]'
```

---

## インスタンスの状態管理

### インスタンスの開始
```bash
# 単一インスタンスを開始
aws ec2 start-instances --instance-ids i-0123456789abcdef0

# 複数インスタンスを同時に開始
aws ec2 start-instances --instance-ids i-0123456789abcdef0 i-0987654321fedcba0
```

### インスタンスの停止
```bash
# 単一インスタンスを停止
aws ec2 stop-instances --instance-ids i-0123456789abcdef0

# 複数インスタンスを同時に停止
aws ec2 stop-instances --instance-ids i-0123456789abcdef0 i-0987654321fedcba0

# 強制停止
aws ec2 stop-instances --instance-ids i-0123456789abcdef0 --force
```

### インスタンスの再起動
```bash
# 単一インスタンスを再起動
aws ec2 reboot-instances --instance-ids i-0123456789abcdef0

# 複数インスタンスを同時に再起動
aws ec2 reboot-instances --instance-ids i-0123456789abcdef0 i-0987654321fedcba0
```

### 起動/停止の完了を待機
```bash
# インスタンスが起動するまで待機
aws ec2 wait instance-running --instance-ids i-0123456789abcdef0

# インスタンスが停止するまで待機
aws ec2 wait instance-stopped --instance-ids i-0123456789abcdef0

# インスタンスが終了するまで待機
aws ec2 wait instance-terminated --instance-ids i-0123456789abcdef0

# インスタンスのステータスチェックが通過するまで待機
aws ec2 wait instance-status-ok --instance-ids i-0123456789abcdef0
```

---

## インスタンスの終了

### 基本的な終了
```bash
# 単一インスタンスを終了
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0

# 複数インスタンスを同時に終了
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0 i-0987654321fedcba0
```

### 終了保護の確認と変更
```bash
# 終了保護の状態を確認
aws ec2 describe-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --attribute disableApiTermination

# 終了保護を有効化
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --disable-api-termination

# 終了保護を無効化
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --no-disable-api-termination
```

### 停止時の動作を変更
```bash
# シャットダウン時に停止するように設定
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --instance-initiated-shutdown-behavior stop

# シャットダウン時に終了するように設定
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --instance-initiated-shutdown-behavior terminate
```

---

## インスタンスの状態確認

### 基本的なインスタンス情報の取得
```bash
# すべてのインスタンスを表示
aws ec2 describe-instances

# 特定のインスタンスを表示
aws ec2 describe-instances --instance-ids i-0123456789abcdef0

# 複数の特定インスタンスを表示
aws ec2 describe-instances --instance-ids i-0123456789abcdef0 i-0987654321fedcba0
```

### 実行中のインスタンスのみを表示
```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"
```

### 特定のタグでフィルタリング
```bash
# 名前でフィルタリング
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=WebServer"

# 環境でフィルタリング
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production"

# 複数のタグでフィルタリング
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" "Name=tag:Type,Values=Web"
```

### インスタンスタイプでフィルタリング
```bash
aws ec2 describe-instances \
  --filters "Name=instance-type,Values=t2.micro,t2.small"
```

### 出力のカスタマイズ
```bash
# インスタンス ID と状態のみを表示
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table

# インスタンス ID、名前、状態、パブリック IP を表示
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table

# JSON で主要情報を表示
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],Type:InstanceType,State:State.Name,IP:PublicIpAddress}' \
  --output json
```

### 実行中のインスタンスの概要
```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
  --output table
```

### インスタンスのステータスチェック
```bash
# すべてのステータスチェックを表示
aws ec2 describe-instance-status

# 特定のインスタンスのステータスを表示
aws ec2 describe-instance-status --instance-ids i-0123456789abcdef0

# システムステータスが impaired のインスタンスを表示
aws ec2 describe-instance-status \
  --filters "Name=system-status.status,Values=impaired"

# インスタンスステータスが impaired のインスタンスを表示
aws ec2 describe-instance-status \
  --filters "Name=instance-status.status,Values=impaired"

# すべてのインスタンスを含める（停止中も表示）
aws ec2 describe-instance-status --include-all-instances
```

### コンソール出力の取得
```bash
# コンソール出力を取得
aws ec2 get-console-output --instance-id i-0123456789abcdef0

# 最新の出力のみを取得
aws ec2 get-console-output \
  --instance-id i-0123456789abcdef0 \
  --latest

# 出力をファイルに保存
aws ec2 get-console-output \
  --instance-id i-0123456789abcdef0 \
  --output text > console-output.txt
```

---

## インスタンス属性の変更

### インスタンスタイプの変更
```bash
# インスタンスを停止
aws ec2 stop-instances --instance-ids i-0123456789abcdef0
aws ec2 wait instance-stopped --instance-ids i-0123456789abcdef0

# インスタンスタイプを変更
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --instance-type "{\"Value\": \"t2.small\"}"

# インスタンスを起動
aws ec2 start-instances --instance-ids i-0123456789abcdef0
```

### ユーザーデータの変更
```bash
# 新しいユーザーデータを Base64 エンコード
USER_DATA=$(echo '#!/bin/bash
yum update -y
yum install -y nginx' | base64)

# ユーザーデータを変更
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --user-data "$USER_DATA"

# ファイルからユーザーデータを変更
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --user-data file://new-user-data.sh
```

### セキュリティグループの変更
```bash
# セキュリティグループを変更（VPC インスタンスのみ）
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --groups sg-0123456789abcdef0 sg-0987654321fedcba0
```

### ソース/宛先チェックの変更
```bash
# ソース/宛先チェックを無効化（NAT インスタンスに必要）
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --no-source-dest-check

# ソース/宛先チェックを有効化
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --source-dest-check
```

### 詳細モニタリングの変更
```bash
# 詳細モニタリングを有効化
aws ec2 monitor-instances --instance-ids i-0123456789abcdef0

# 詳細モニタリングを無効化
aws ec2 unmonitor-instances --instance-ids i-0123456789abcdef0
```

### インスタンスメタデータオプションの変更
```bash
# IMDSv2 を必須に設定
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required \
  --http-endpoint enabled

# IMDSv1 も許可
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens optional

# メタデータエンドポイントを無効化
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-endpoint disabled
```

### EBS 最適化の変更
```bash
# EBS 最適化を有効化
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --ebs-optimized

# EBS 最適化を無効化
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --no-ebs-optimized
```

### インスタンスのタグを変更
```bash
# タグを追加
aws ec2 create-tags \
  --resources i-0123456789abcdef0 \
  --tags Key=Environment,Value=Production Key=Owner,Value=DevOps

# タグを削除
aws ec2 delete-tags \
  --resources i-0123456789abcdef0 \
  --tags Key=OldTag
```

### カーネル ID またはラムディスク ID の変更
```bash
# カーネル ID を変更
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --kernel aki-12345678

# ラムディスク ID を変更
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --ramdisk ari-12345678
```

---

## 実践的なシナリオ

### シナリオ 1: Web サーバーのデプロイ
```bash
#!/bin/bash

# 変数の設定
AMI_ID="ami-0c55b159cbfafe1f0"
INSTANCE_TYPE="t2.micro"
KEY_NAME="my-key-pair"
SECURITY_GROUP="sg-0123456789abcdef0"
SUBNET_ID="subnet-0123456789abcdef0"

# ユーザーデータの作成
cat > web-server-setup.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# シンプルな Web ページを作成
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
</head>
<body>
    <h1>Welcome to my web server!</h1>
    <p>Instance ID: $(ec2-metadata --instance-id | cut -d " " -f 2)</p>
    <p>Availability Zone: $(ec2-metadata --availability-zone | cut -d " " -f 2)</p>
</body>
</html>
HTML
EOF

# インスタンスを起動
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP" \
  --subnet-id "$SUBNET_ID" \
  --user-data file://web-server-setup.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=WebServer},{Key=Environment,Value=Production}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "インスタンス ID: $INSTANCE_ID"

# インスタンスが実行中になるまで待機
echo "インスタンスの起動を待機中..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# パブリック IP アドレスを取得
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "パブリック IP: $PUBLIC_IP"
echo "Web サーバーにアクセス: http://$PUBLIC_IP"
```

### シナリオ 2: 複数環境のインスタンス管理
```bash
#!/bin/bash

# 環境ごとにインスタンスを起動
deploy_environment() {
  local ENV_NAME=$1
  local INSTANCE_TYPE=$2
  local COUNT=$3
  
  echo "環境 $ENV_NAME のインスタンスを起動中..."
  
  aws ec2 run-instances \
    --image-id ami-0c55b159cbfafe1f0 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name my-key-pair \
    --security-group-ids sg-0123456789abcdef0 \
    --subnet-id subnet-0123456789abcdef0 \
    --count "$COUNT" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${ENV_NAME}-Server},{Key=Environment,Value=${ENV_NAME}}]"
}

# 開発環境
deploy_environment "Development" "t2.micro" 2

# ステージング環境
deploy_environment "Staging" "t2.small" 2

# 本番環境
deploy_environment "Production" "t2.medium" 3

# 各環境のインスタンスを確認
for env in Development Staging Production; do
  echo "=== $env 環境 ==="
  aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=$env" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,PrivateIpAddress]' \
    --output table
done
```

### シナリオ 3: メンテナンスウィンドウでのインスタンス操作
```bash
#!/bin/bash

# メンテナンス対象のインスタンスを取得
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:MaintenanceGroup,Values=Group1" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "メンテナンス対象のインスタンスがありません"
  exit 0
fi

echo "メンテナンス対象: $INSTANCE_IDS"

# インスタンスを停止
echo "インスタンスを停止中..."
aws ec2 stop-instances --instance-ids $INSTANCE_IDS

# 停止完了を待機
echo "停止完了を待機中..."
aws ec2 wait instance-stopped --instance-ids $INSTANCE_IDS

# インスタンスタイプを変更
echo "インスタンスタイプを変更中..."
for INSTANCE_ID in $INSTANCE_IDS; do
  aws ec2 modify-instance-attribute \
    --instance-id "$INSTANCE_ID" \
    --instance-type "{\"Value\": \"t2.small\"}"
  echo "  $INSTANCE_ID のタイプを変更しました"
done

# インスタンスを再起動
echo "インスタンスを起動中..."
aws ec2 start-instances --instance-ids $INSTANCE_IDS

# 起動完了を待機
echo "起動完了を待機中..."
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS

echo "メンテナンス完了"
```

### シナリオ 4: 自動スケールアウト
```bash
#!/bin/bash

# 現在の負荷をシミュレート（実際は CloudWatch メトリクスを使用）
CURRENT_INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:AutoScale,Values=true" "Name=instance-state-name,Values=running" \
  --query 'length(Reservations[].Instances[])' \
  --output text)

MAX_INSTANCES=10
SCALE_OUT_COUNT=2

echo "現在のインスタンス数: $CURRENT_INSTANCES"

if [ "$CURRENT_INSTANCES" -lt "$MAX_INSTANCES" ]; then
  echo "インスタンスをスケールアウト中..."
  
  # 既存のインスタンスから設定を取得
  REFERENCE_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:AutoScale,Values=true" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  
  # 新しいインスタンスを起動
  aws ec2 run-instances \
    --image-id ami-0c55b159cbfafe1f0 \
    --instance-type t2.micro \
    --key-name my-key-pair \
    --security-group-ids sg-0123456789abcdef0 \
    --subnet-id subnet-0123456789abcdef0 \
    --count $SCALE_OUT_COUNT \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=AutoScale,Value=true},{Key=Name,Value=AutoScaled-Server}]'
  
  echo "$SCALE_OUT_COUNT 個のインスタンスを追加しました"
else
  echo "最大インスタンス数に達しています"
fi
```

### シナリオ 5: インスタンスのヘルスチェックと自動復旧
```bash
#!/bin/bash

check_instance_health() {
  local INSTANCE_ID=$1
  
  # ステータスチェックを取得
  STATUS=$(aws ec2 describe-instance-status \
    --instance-ids "$INSTANCE_ID" \
    --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' \
    --output text)
  
  SYSTEM_STATUS=$(echo "$STATUS" | awk '{print $1}')
  INSTANCE_STATUS=$(echo "$STATUS" | awk '{print $2}')
  
  echo "インスタンス $INSTANCE_ID:"
  echo "  システムステータス: $SYSTEM_STATUS"
  echo "  インスタンスステータス: $INSTANCE_STATUS"
  
  # ステータスが impaired の場合
  if [ "$SYSTEM_STATUS" = "impaired" ] || [ "$INSTANCE_STATUS" = "impaired" ]; then
    echo "  警告: インスタンスに問題があります"
    
    # 再起動を試みる
    echo "  インスタンスを再起動します..."
    aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"
    
    # 5分待機
    sleep 300
    
    # 再度チェック
    NEW_STATUS=$(aws ec2 describe-instance-status \
      --instance-ids "$INSTANCE_ID" \
      --query 'InstanceStatuses[0].InstanceStatus.Status' \
      --output text)
    
    if [ "$NEW_STATUS" = "impaired" ]; then
      echo "  エラー: 再起動後も問題が続いています"
      echo "  管理者に通知してください"
      # ここで通知を送信（SNS など）
    else
      echo "  成功: インスタンスが復旧しました"
    fi
  else
    echo "  正常: インスタンスは健全です"
  fi
}

# すべての本番インスタンスをチェック
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
  check_instance_health "$INSTANCE_ID"
  echo ""
done
```

### シナリオ 6: コスト最適化 - 未使用インスタンスの検出と停止
```bash
#!/bin/bash

# 低使用率のインスタンスを検出（実際は CloudWatch メトリクスを使用）
detect_idle_instances() {
  echo "=== 未使用インスタンスの検出 ==="
  
  # 特定のタグがないインスタンスを検索
  UNTAGGED_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[?!not_null(Tags[?Key==`Owner`])].[InstanceId,LaunchTime]' \
    --output text)
  
  if [ -n "$UNTAGGED_INSTANCES" ]; then
    echo "所有者タグのないインスタンス:"
    echo "$UNTAGGED_INSTANCES"
  fi
  
  # 古いインスタンスを検索（30日以上実行中）
  THIRTY_DAYS_AGO=$(date -u -v-30d +"%Y-%m-%d")
  
  OLD_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[?LaunchTime<='${THIRTY_DAYS_AGO}'].[InstanceId,LaunchTime,Tags[?Key=='Name'].Value|[0]]" \
    --output table)
  
  if [ -n "$OLD_INSTANCES" ]; then
    echo "30日以上実行中のインスタンス:"
    echo "$OLD_INSTANCES"
  fi
}

# 開発環境の夜間停止
stop_dev_instances_after_hours() {
  local CURRENT_HOUR=$(date +%H)
  
  # 19時から7時の間は停止
  if [ "$CURRENT_HOUR" -ge 19 ] || [ "$CURRENT_HOUR" -lt 7 ]; then
    echo "営業時間外: 開発環境のインスタンスを停止します"
    
    DEV_INSTANCES=$(aws ec2 describe-instances \
      --filters "Name=tag:Environment,Values=Development" "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text)
    
    if [ -n "$DEV_INSTANCES" ]; then
      aws ec2 stop-instances --instance-ids $DEV_INSTANCES
      echo "停止したインスタンス: $DEV_INSTANCES"
    fi
  fi
}

detect_idle_instances
stop_dev_instances_after_hours
```

### シナリオ 7: バックアップと AMI 作成
```bash
#!/bin/bash

# インスタンスから AMI を作成
create_instance_backup() {
  local INSTANCE_ID=$1
  local BACKUP_NAME=$2
  
  echo "インスタンス $INSTANCE_ID のバックアップを作成中..."
  
  # インスタンス名を取得
  INSTANCE_NAME=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value' \
    --output text)
  
  # 現在の日時を取得
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  
  # AMI を作成（再起動なし）
  AMI_ID=$(aws ec2 create-image \
    --instance-id "$INSTANCE_ID" \
    --name "${BACKUP_NAME:-$INSTANCE_NAME}-backup-$TIMESTAMP" \
    --description "Backup of $INSTANCE_NAME created on $TIMESTAMP" \
    --no-reboot \
    --tag-specifications "ResourceType=image,Tags=[{Key=Name,Value=${BACKUP_NAME:-$INSTANCE_NAME}-backup},{Key=BackupDate,Value=$TIMESTAMP},{Key=SourceInstance,Value=$INSTANCE_ID}]" \
    --query 'ImageId' \
    --output text)
  
  echo "AMI 作成開始: $AMI_ID"
  
  # AMI が利用可能になるまで待機
  aws ec2 wait image-available --image-ids "$AMI_ID"
  
  echo "AMI 作成完了: $AMI_ID"
  
  # 古いバックアップを削除（7日以上前）
  SEVEN_DAYS_AGO=$(date -u -v-7d +"%Y%m%d")
  
  OLD_AMIS=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=tag:SourceInstance,Values=$INSTANCE_ID" \
    --query "Images[?CreationDate<='${SEVEN_DAYS_AGO}'].ImageId" \
    --output text)
  
  if [ -n "$OLD_AMIS" ]; then
    echo "古いバックアップを削除: $OLD_AMIS"
    for OLD_AMI in $OLD_AMIS; do
      aws ec2 deregister-image --image-id "$OLD_AMI"
    done
  fi
}

# 本番環境のすべてのインスタンスをバックアップ
PRODUCTION_INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

for INSTANCE_ID in $PRODUCTION_INSTANCES; do
  create_instance_backup "$INSTANCE_ID"
done
```

### シナリオ 8: ローリングアップデート
```bash
#!/bin/bash

# ローリングアップデートの実行
rolling_update() {
  local TAG_KEY=$1
  local TAG_VALUE=$2
  local NEW_AMI=$3
  
  # 対象インスタンスを取得
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
  
  echo "ローリングアップデート対象: $INSTANCE_IDS"
  
  for INSTANCE_ID in $INSTANCE_IDS; do
    echo "=== インスタンス $INSTANCE_ID を更新中 ==="
    
    # インスタンス情報を取得
    INSTANCE_INFO=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0]')
    
    INSTANCE_TYPE=$(echo "$INSTANCE_INFO" | jq -r '.InstanceType')
    KEY_NAME=$(echo "$INSTANCE_INFO" | jq -r '.KeyName')
    SECURITY_GROUPS=$(echo "$INSTANCE_INFO" | jq -r '.SecurityGroups[].GroupId' | tr '\n' ' ')
    SUBNET_ID=$(echo "$INSTANCE_INFO" | jq -r '.SubnetId')
    TAGS=$(echo "$INSTANCE_INFO" | jq -c '.Tags')
    
    # 古いインスタンスを終了
    echo "古いインスタンスを終了..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
    
    # 新しいインスタンスを起動
    echo "新しいインスタンスを起動..."
    NEW_INSTANCE_ID=$(aws ec2 run-instances \
      --image-id "$NEW_AMI" \
      --instance-type "$INSTANCE_TYPE" \
      --key-name "$KEY_NAME" \
      --security-group-ids $SECURITY_GROUPS \
      --subnet-id "$SUBNET_ID" \
      --tag-specifications "ResourceType=instance,Tags=$TAGS" \
      --query 'Instances[0].InstanceId' \
      --output text)
    
    echo "新しいインスタンス ID: $NEW_INSTANCE_ID"
    
    # インスタンスが実行中になるまで待機
    aws ec2 wait instance-running --instance-ids "$NEW_INSTANCE_ID"
    
    # ステータスチェックが通過するまで待機
    aws ec2 wait instance-status-ok --instance-ids "$NEW_INSTANCE_ID"
    
    echo "インスタンス $INSTANCE_ID の更新完了（新 ID: $NEW_INSTANCE_ID）"
    echo "次のインスタンスまで30秒待機..."
    sleep 30
  done
  
  echo "ローリングアップデート完了"
}

# 使用例
rolling_update "Application" "WebServer" "ami-0new123456789abcd"
```

---

## 参考リンク
- [AWS CLI EC2 コマンドリファレンス](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
- [EC2 インスタンスタイプ](https://aws.amazon.com/ec2/instance-types/)
- [EC2 ユーザーガイド](https://docs.aws.amazon.com/ec2/)