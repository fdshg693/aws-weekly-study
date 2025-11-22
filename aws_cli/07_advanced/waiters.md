# AWS CLI Waiters

## 目次
- [Waitersとは](#waitersとは)
- [基本的な使用](#基本的な使用)
- [利用可能なWaiters](#利用可能なwaiters)
- [タイムアウトとリトライ](#タイムアウトとリトライ)
- [カスタムWaiters](#カスタムwaiters)
- [実践的な例](#実践的な例)

## Waitersとは

WaitersはAWSリソースが特定の状態になるまで待機する機能です。ポーリングとタイムアウトを自動的に処理します。

### Waitersの利点
- リソースの状態変化を自動的に監視
- ポーリングロジックの実装不要
- タイムアウトとエラーハンドリングが組み込み
- スクリプトの信頼性向上

### 基本概念
```bash
# 一般的な構文
aws <service> wait <waiter-name> [options]

# 例：インスタンスが起動するまで待機
aws ec2 wait instance-running --instance-ids i-1234567890abcdef0

# 成功時は何も出力せず、失敗時はエラーを返す
echo $?  # 0: 成功, 255: 失敗
```

## 基本的な使用

### EC2 Waiters
```bash
# インスタンスが起動するまで待機
aws ec2 wait instance-running \
  --instance-ids i-1234567890abcdef0

# インスタンスが停止するまで待機
aws ec2 wait instance-stopped \
  --instance-ids i-1234567890abcdef0

# インスタンスが終了するまで待機
aws ec2 wait instance-terminated \
  --instance-ids i-1234567890abcdef0

# インスタンスのステータスチェックがOKになるまで待機
aws ec2 wait instance-status-ok \
  --instance-ids i-1234567890abcdef0

# システムステータスチェックがOKになるまで待機
aws ec2 wait system-status-ok \
  --instance-ids i-1234567890abcdef0

# スナップショットが完了するまで待機
aws ec2 wait snapshot-completed \
  --snapshot-ids snap-1234567890abcdef0

# ボリュームが利用可能になるまで待機
aws ec2 wait volume-available \
  --volume-ids vol-1234567890abcdef0

# イメージが利用可能になるまで待機
aws ec2 wait image-available \
  --image-ids ami-1234567890abcdef0
```

### CloudFormation Waiters
```bash
# スタック作成が完了するまで待機
aws cloudformation wait stack-create-complete \
  --stack-name my-stack

# スタック更新が完了するまで待機
aws cloudformation wait stack-update-complete \
  --stack-name my-stack

# スタック削除が完了するまで待機
aws cloudformation wait stack-delete-complete \
  --stack-name my-stack

# チェンジセット作成が完了するまで待機
aws cloudformation wait change-set-create-complete \
  --stack-name my-stack \
  --change-set-name my-change-set

# スタックがEXISTS状態になるまで待機
aws cloudformation wait stack-exists \
  --stack-name my-stack

# スタックインポートが完了するまで待機
aws cloudformation wait stack-import-complete \
  --stack-name my-stack

# ロールバックが完了するまで待機
aws cloudformation wait stack-rollback-complete \
  --stack-name my-stack
```

### RDS Waiters
```bash
# DBインスタンスが利用可能になるまで待機
aws rds wait db-instance-available \
  --db-instance-identifier mydb

# DBインスタンスが削除されるまで待機
aws rds wait db-instance-deleted \
  --db-instance-identifier mydb

# DBスナップショットが利用可能になるまで待機
aws rds wait db-snapshot-available \
  --db-snapshot-identifier my-snapshot

# DBスナップショットが完了するまで待機
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier my-snapshot

# DBクラスターが利用可能になるまで待機
aws rds wait db-cluster-available \
  --db-cluster-identifier my-cluster

# DBクラスターが削除されるまで待機
aws rds wait db-cluster-deleted \
  --db-cluster-identifier my-cluster
```

### Lambda Waiters
```bash
# 関数が存在するまで待機
aws lambda wait function-exists \
  --function-name my-function

# 関数が有効になるまで待機
aws lambda wait function-active \
  --function-name my-function

# 関数更新が完了するまで待機
aws lambda wait function-updated \
  --function-name my-function
```

### ELB Waiters
```bash
# ロードバランサーが利用可能になるまで待機
aws elbv2 wait load-balancer-available \
  --load-balancer-arns arn:aws:elasticloadbalancing:...

# ロードバランサーが存在するまで待機
aws elbv2 wait load-balancer-exists \
  --load-balancer-arns arn:aws:elasticloadbalancing:...

# ターゲットが登録解除されるまで待機
aws elbv2 wait target-deregistered \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --targets Id=i-1234567890abcdef0

# ターゲットが登録されるまで待機
aws elbv2 wait target-in-service \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --targets Id=i-1234567890abcdef0
```

## 利用可能なWaiters

### Waitersの一覧を確認
```bash
# サービスごとの利用可能なWaitersを確認
aws ec2 wait help

aws cloudformation wait help

aws rds wait help

# すべてのWaitersをリスト
for SERVICE in ec2 cloudformation rds lambda elbv2 s3api; do
  echo "=== $SERVICE ==="
  aws $SERVICE wait help 2>/dev/null | grep "^       o" | sed 's/^       o /  - /'
  echo ""
done
```

### 主要サービスのWaiters

#### S3
```bash
# バケットが存在するまで待機
aws s3api wait bucket-exists --bucket my-bucket

# バケットが存在しなくなるまで待機
aws s3api wait bucket-not-exists --bucket my-bucket

# オブジェクトが存在するまで待機
aws s3api wait object-exists --bucket my-bucket --key myfile.txt

# オブジェクトが存在しなくなるまで待機
aws s3api wait object-not-exists --bucket my-bucket --key myfile.txt
```

#### DynamoDB
```bash
# テーブルが存在するまで待機
aws dynamodb wait table-exists --table-name my-table

# テーブルが存在しなくなるまで待機
aws dynamodb wait table-not-exists --table-name my-table
```

#### ECS
```bash
# サービスが安定するまで待機
aws ecs wait services-stable --cluster my-cluster --services my-service

# サービスが非アクティブになるまで待機
aws ecs wait services-inactive --cluster my-cluster --services my-service

# タスクが実行中になるまで待機
aws ecs wait tasks-running --cluster my-cluster --tasks task-id

# タスクが停止するまで待機
aws ecs wait tasks-stopped --cluster my-cluster --tasks task-id
```

## タイムアウトとリトライ

### デフォルトの動作
```bash
# ほとんどのWaitersのデフォルト設定：
# - 最大試行回数: 40回
# - 待機間隔: 15秒
# - タイムアウト: 約10分（40 × 15秒）

# 例：インスタンスが起動するまで待機（最大10分）
aws ec2 wait instance-running --instance-ids i-1234567890abcdef0
```

### タイムアウトのカスタマイズ
```bash
# 設定ファイルでタイムアウトを変更
cat > ~/.aws/cli/waiter_config.json << 'EOF'
{
  "version": 2,
  "waiters": {
    "InstanceRunning": {
      "delay": 5,
      "maxAttempts": 120
    }
  }
}
EOF

# カスタムWaiter設定を使用
aws ec2 wait instance-running \
  --instance-ids i-1234567890abcdef0 \
  --cli-read-timeout 600
```

### エラーハンドリング
```bash
#!/bin/bash
# wait-with-error-handling.sh

INSTANCE_ID="$1"

echo "Waiting for instance $INSTANCE_ID to be running..."

if aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"; then
  echo "✅ Instance is now running"
  exit 0
else
  EXIT_CODE=$?
  echo "❌ Wait failed with exit code: $EXIT_CODE"
  
  # インスタンスの現在の状態を確認
  STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)
  
  echo "Current state: $STATE"
  exit $EXIT_CODE
fi
```

## カスタムWaiters

### カスタムWaiter定義
```bash
# カスタムWaiter設定ファイルを作成
cat > custom-waiters.json << 'EOF'
{
  "version": 2,
  "waiters": {
    "InstanceHealthy": {
      "operation": "DescribeInstanceStatus",
      "delay": 15,
      "maxAttempts": 40,
      "acceptors": [
        {
          "expected": "ok",
          "matcher": "pathAll",
          "state": "success",
          "argument": "InstanceStatuses[].InstanceStatus.Status"
        },
        {
          "expected": "impaired",
          "matcher": "pathAny",
          "state": "failure",
          "argument": "InstanceStatuses[].InstanceStatus.Status"
        }
      ]
    },
    "AllInstancesRunning": {
      "operation": "DescribeInstances",
      "delay": 10,
      "maxAttempts": 60,
      "acceptors": [
        {
          "expected": "running",
          "matcher": "pathAll",
          "state": "success",
          "argument": "Reservations[].Instances[].State.Name"
        },
        {
          "expected": "terminated",
          "matcher": "pathAny",
          "state": "failure",
          "argument": "Reservations[].Instances[].State.Name"
        }
      ]
    }
  }
}
EOF

# カスタムWaiterを使用（AWS CLIの低レベルAPIが必要）
```

### Waiterのシミュレーション
```bash
#!/bin/bash
# custom-wait.sh - カスタムWaiter実装

wait_for_condition() {
  local MAX_ATTEMPTS=40
  local DELAY=15
  local ATTEMPT=1
  
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # 条件をチェック（カスタマイズ可能）
    STATE=$(aws ec2 describe-instances \
      --instance-ids "$1" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text)
    
    if [ "$STATE" = "running" ]; then
      echo "✅ Condition met!"
      return 0
    elif [ "$STATE" = "terminated" ]; then
      echo "❌ Failure condition met"
      return 1
    fi
    
    echo "Current state: $STATE (waiting ${DELAY}s...)"
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
  done
  
  echo "❌ Timeout after $MAX_ATTEMPTS attempts"
  return 255
}

# 使用例
wait_for_condition i-1234567890abcdef0
```

## 実践的な例

### デプロイメントスクリプト
```bash
#!/bin/bash
# deploy-with-wait.sh - Waitersを使った安全なデプロイ

INSTANCE_ID="$1"

echo "=== Starting deployment ==="

# 1. インスタンスを停止
echo "Stopping instance..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"

echo "Waiting for instance to stop..."
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

echo "✅ Instance stopped"

# 2. AMIを作成
echo "Creating AMI..."
IMAGE_ID=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "backup-$(date +%Y%m%d-%H%M%S)" \
  --query 'ImageId' \
  --output text)

echo "AMI ID: $IMAGE_ID"
echo "Waiting for AMI to be available..."
aws ec2 wait image-available --image-ids "$IMAGE_ID"

echo "✅ AMI created"

# 3. インスタンスを起動
echo "Starting instance..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID"

echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo "✅ Instance running"

# 4. ステータスチェックを待機
echo "Waiting for status checks..."
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

echo "✅ Status checks passed"

echo ""
echo "=== Deployment completed successfully ==="
```

### CloudFormationデプロイ
```bash
#!/bin/bash
# cfn-deploy-with-wait.sh - CloudFormationスタックのデプロイ

STACK_NAME="$1"
TEMPLATE_FILE="$2"

echo "Deploying stack: $STACK_NAME"

# スタックが存在するか確認
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &>/dev/null; then
  echo "Stack exists. Updating..."
  
  # 更新
  aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --capabilities CAPABILITY_NAMED_IAM
  
  if [ $? -eq 0 ]; then
    echo "Waiting for stack update to complete..."
    
    if aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"; then
      echo "✅ Stack updated successfully"
    else
      echo "❌ Stack update failed"
      
      # 失敗イベントを表示
      aws cloudformation describe-stack-events \
        --stack-name "$STACK_NAME" \
        --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`]' \
        --output table
      
      exit 1
    fi
  else
    echo "No updates to perform"
  fi
else
  echo "Stack does not exist. Creating..."
  
  # 作成
  aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --capabilities CAPABILITY_NAMED_IAM
  
  echo "Waiting for stack creation to complete..."
  
  if aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"; then
    echo "✅ Stack created successfully"
  else
    echo "❌ Stack creation failed"
    exit 1
  fi
fi

# 出力を表示
echo ""
echo "=== Stack Outputs ==="
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
```

### RDSメンテナンス
```bash
#!/bin/bash
# rds-maintenance.sh - RDSメンテナンス自動化

DB_INSTANCE="$1"

echo "=== RDS Maintenance Script ==="
echo "DB Instance: $DB_INSTANCE"
echo ""

# 1. スナップショット作成
SNAPSHOT_ID="$DB_INSTANCE-$(date +%Y%m%d-%H%M%S)"
echo "Creating snapshot: $SNAPSHOT_ID"

aws rds create-db-snapshot \
  --db-instance-identifier "$DB_INSTANCE" \
  --db-snapshot-identifier "$SNAPSHOT_ID"

echo "Waiting for snapshot to complete..."
aws rds wait db-snapshot-completed --db-snapshot-identifier "$SNAPSHOT_ID"

echo "✅ Snapshot created"

# 2. インスタンスの変更（例：インスタンスタイプ変更）
echo ""
echo "Modifying DB instance..."

aws rds modify-db-instance \
  --db-instance-identifier "$DB_INSTANCE" \
  --db-instance-class db.t3.medium \
  --apply-immediately

echo "Waiting for modification to complete..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"

echo "✅ DB instance modified"

# 3. 接続テスト
echo ""
echo "Verifying DB instance..."

ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "DB Endpoint: $ENDPOINT"
echo ""
echo "=== Maintenance completed ==="
```

### マルチリージョンデプロイ
```bash
#!/bin/bash
# multi-region-deploy.sh - 複数リージョンへの並列デプロイ

REGIONS=("us-east-1" "eu-west-1" "ap-northeast-1")
STACK_NAME="my-application"
TEMPLATE_FILE="template.yaml"

deploy_to_region() {
  local REGION=$1
  
  echo "[$REGION] Deploying stack..."
  
  aws cloudformation create-stack \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --capabilities CAPABILITY_NAMED_IAM
  
  echo "[$REGION] Waiting for stack creation..."
  
  if aws cloudformation wait stack-create-complete \
    --region "$REGION" \
    --stack-name "$STACK_NAME"; then
    echo "[$REGION] ✅ Deployment successful"
  else
    echo "[$REGION] ❌ Deployment failed"
    return 1
  fi
}

# 並列デプロイ
for REGION in "${REGIONS[@]}"; do
  deploy_to_region "$REGION" &
done

# すべての完了を待機
wait

echo ""
echo "=== All regions deployed ==="
```

### タイムアウト監視
```bash
#!/bin/bash
# wait-with-timeout.sh - タイムアウト付きWait

wait_with_timeout() {
  local SERVICE=$1
  local WAITER=$2
  local TIMEOUT=$3
  shift 3
  local ARGS="$@"
  
  echo "Waiting for $SERVICE $WAITER (timeout: ${TIMEOUT}s)..."
  
  # バックグラウンドでWaiterを実行
  aws $SERVICE wait $WAITER $ARGS &
  local WAIT_PID=$!
  
  # タイムアウト監視
  (
    sleep $TIMEOUT
    if kill -0 $WAIT_PID 2>/dev/null; then
      echo "❌ Timeout after ${TIMEOUT}s"
      kill $WAIT_PID 2>/dev/null
    fi
  ) &
  local TIMEOUT_PID=$!
  
  # Waiterの完了を待機
  if wait $WAIT_PID 2>/dev/null; then
    kill $TIMEOUT_PID 2>/dev/null
    echo "✅ Wait completed successfully"
    return 0
  else
    echo "❌ Wait failed"
    return 1
  fi
}

# 使用例
wait_with_timeout ec2 instance-running 300 --instance-ids i-1234567890abcdef0
```

### 進捗表示付きWait
```bash
#!/bin/bash
# wait-with-progress.sh - 進捗表示付きWait

INSTANCE_ID="$1"
MAX_ATTEMPTS=40
DELAY=15

echo "Waiting for instance $INSTANCE_ID to be running..."

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)
  
  # プログレスバー
  PROGRESS=$((i * 100 / MAX_ATTEMPTS))
  FILLED=$((PROGRESS / 2))
  EMPTY=$((50 - FILLED))
  
  printf "\r[%-50s] %d%% - State: %-15s (Attempt %d/%d)" \
    "$(printf '#%.0s' $(seq 1 $FILLED))$(printf ' %.0s' $(seq 1 $EMPTY))" \
    "$PROGRESS" \
    "$STATE" \
    "$i" \
    "$MAX_ATTEMPTS"
  
  if [ "$STATE" = "running" ]; then
    echo ""
    echo "✅ Instance is running"
    exit 0
  elif [ "$STATE" = "terminated" ]; then
    echo ""
    echo "❌ Instance terminated"
    exit 1
  fi
  
  sleep $DELAY
done

echo ""
echo "❌ Timeout"
exit 255
```

このドキュメントでは、AWS CLI Waitersの使い方を包括的に説明しました。Waitersを活用して、信頼性の高い自動化スクリプトを作成してください。
