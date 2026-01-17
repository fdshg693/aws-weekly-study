# CloudFormation スタック操作

## 目次
- [スタックの作成](#スタックの作成)
- [スタックの更新](#スタックの更新)
- [スタックの削除](#スタックの削除)
- [スタック情報の取得](#スタック情報の取得)
- [スタックイベントの確認](#スタックイベントの確認)
- [スタックリソースの確認](#スタックリソースの確認)
- [スタックドリフトの検出](#スタックドリフトの検出)
- [実践的な例](#実践的な例)

## スタックの作成

### 基本的なスタック作成
```bash
# シンプルなスタック作成
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml

# S3上のテンプレートから作成
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-url https://s3.amazonaws.com/my-bucket/template.yaml

# パラメータ付きで作成
aws cloudformation create-stack \
  --stack-name my-vpc-stack \
  --template-body file://vpc-template.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=Production \
    ParameterKey=VpcCIDR,ParameterValue=10.0.0.0/16
```

### IAM機能の有効化
```bash
# IAMリソースを含むスタック
aws cloudformation create-stack \
  --stack-name my-iam-stack \
  --template-body file://iam-template.yaml \
  --capabilities CAPABILITY_IAM

# カスタム名前のIAMリソース
aws cloudformation create-stack \
  --stack-name my-custom-iam-stack \
  --template-body file://iam-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM

# 両方の機能を有効化
aws cloudformation create-stack \
  --stack-name my-advanced-stack \
  --template-body file://advanced-template.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

### タグとロールバック設定
```bash
# タグ付きスタック作成
aws cloudformation create-stack \
  --stack-name my-tagged-stack \
  --template-body file://template.yaml \
  --tags \
    Key=Environment,Value=Production \
    Key=Project,Value=WebApp \
    Key=CostCenter,Value=Engineering

# ロールバック無効化（デバッグ用）
aws cloudformation create-stack \
  --stack-name my-debug-stack \
  --template-body file://template.yaml \
  --disable-rollback

# タイムアウト設定
aws cloudformation create-stack \
  --stack-name my-timed-stack \
  --template-body file://template.yaml \
  --timeout-in-minutes 30
```

### 通知とSNS
```bash
# SNS通知付きスタック作成
aws cloudformation create-stack \
  --stack-name my-notified-stack \
  --template-body file://template.yaml \
  --notification-arns arn:aws:sns:us-east-1:123456789012:MyTopic
```

### スタック作成の待機
```bash
# スタック作成を開始
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml

# 作成完了を待機
aws cloudformation wait stack-create-complete \
  --stack-name my-stack

echo "Stack created successfully!"
```

## スタックの更新

### 基本的な更新
```bash
# テンプレートを更新
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://updated-template.yaml

# パラメータのみ更新
aws cloudformation update-stack \
  --stack-name my-stack \
  --use-previous-template \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.medium

# 一部パラメータは前の値を使用
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://updated-template.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.large \
    ParameterKey=KeyName,UsePreviousValue=true
```

### 更新完了の待機
```bash
# 更新を実行
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://updated-template.yaml

# 更新完了を待機
aws cloudformation wait stack-update-complete \
  --stack-name my-stack

echo "Stack updated successfully!"
```

### スタックポリシー
```bash
# スタックポリシーを作成
cat > stack-policy.json << 'EOF'
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "Update:*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "Update:Delete",
      "Resource": "LogicalResourceId/ProductionDatabase"
    }
  ]
}
EOF

# スタック作成時にポリシーを適用
aws cloudformation create-stack \
  --stack-name my-protected-stack \
  --template-body file://template.yaml \
  --stack-policy-body file://stack-policy.json

# 既存スタックにポリシーを設定
aws cloudformation set-stack-policy \
  --stack-name my-stack \
  --stack-policy-body file://stack-policy.json
```

## スタックの削除

### 基本的な削除
```bash
# スタックを削除
aws cloudformation delete-stack --stack-name my-stack

# 削除完了を待機
aws cloudformation wait stack-delete-complete --stack-name my-stack

echo "Stack deleted successfully!"
```

### 保持するリソースの指定
```bash
# 特定リソースを保持して削除
aws cloudformation delete-stack \
  --stack-name my-stack \
  --retain-resources MyS3Bucket MyDynamoDBTable
```

### 削除保護
```bash
# 削除保護を有効化
aws cloudformation update-termination-protection \
  --enable-termination-protection \
  --stack-name my-production-stack

# 削除保護を無効化
aws cloudformation update-termination-protection \
  --no-enable-termination-protection \
  --stack-name my-stack
```

## スタック情報の取得

### スタックの一覧表示
```bash
# すべてのスタックを表示
aws cloudformation list-stacks

# アクティブなスタックのみ
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# スタック名のみ表示
aws cloudformation list-stacks \
  --query 'StackSummaries[?StackStatus==`CREATE_COMPLETE`].StackName' \
  --output table
```

### スタックの詳細情報
```bash
# スタックの詳細を取得
aws cloudformation describe-stacks --stack-name my-stack

# 特定の情報のみ抽出
aws cloudformation describe-stacks \
  --stack-name my-stack \
  --query 'Stacks[0].[StackName,StackStatus,CreationTime]' \
  --output table

# 出力パラメータを表示
aws cloudformation describe-stacks \
  --stack-name my-stack \
  --query 'Stacks[0].Outputs' \
  --output table
```

### パラメータの取得
```bash
# スタックパラメータを表示
aws cloudformation describe-stacks \
  --stack-name my-stack \
  --query 'Stacks[0].Parameters'
```

## スタックイベントの確認

### イベント一覧
```bash
# 最新のイベントを表示
aws cloudformation describe-stack-events \
  --stack-name my-stack

# イベントを時系列で表示
aws cloudformation describe-stack-events \
  --stack-name my-stack \
  --query 'StackEvents[].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table

# 失敗イベントのみ表示
aws cloudformation describe-stack-events \
  --stack-name my-stack \
  --query 'StackEvents[?contains(ResourceStatus, `FAILED`)]'
```

### リアルタイムモニタリング
```bash
#!/bin/bash
STACK_NAME="$1"

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 <stack-name>"
  exit 1
fi

echo "Monitoring stack: $STACK_NAME"
echo "Press Ctrl+C to stop"
echo ""

LAST_EVENT_TIME=""

while true; do
  LATEST_EVENT=$(aws cloudformation describe-stack-events \
    --stack-name $STACK_NAME \
    --max-items 1 \
    --query 'StackEvents[0]')
  
  EVENT_TIME=$(echo $LATEST_EVENT | jq -r '.Timestamp')
  
  if [ "$EVENT_TIME" != "$LAST_EVENT_TIME" ]; then
    echo $LATEST_EVENT | jq -r '"\(.Timestamp) | \(.ResourceStatus) | \(.LogicalResourceId) | \(.ResourceStatusReason // "N/A")"'
    LAST_EVENT_TIME=$EVENT_TIME
  fi
  
  sleep 5
done
```

## スタックリソースの確認

### リソース一覧
```bash
# すべてのリソースを表示
aws cloudformation describe-stack-resources \
  --stack-name my-stack

# リソースの概要を表形式で表示
aws cloudformation describe-stack-resources \
  --stack-name my-stack \
  --query 'StackResources[].[LogicalResourceId,ResourceType,ResourceStatus,PhysicalResourceId]' \
  --output table

# 特定タイプのリソースのみ
aws cloudformation describe-stack-resources \
  --stack-name my-stack \
  --query 'StackResources[?ResourceType==`AWS::EC2::Instance`]'
```

### 特定リソースの詳細
```bash
# 論理IDでリソースを取得
aws cloudformation describe-stack-resource \
  --stack-name my-stack \
  --logical-resource-id MyEC2Instance

# 物理IDを取得
aws cloudformation describe-stack-resource \
  --stack-name my-stack \
  --logical-resource-id MyEC2Instance \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text
```

### リソースのエクスポート情報
```bash
# すべてのエクスポート値を表示
aws cloudformation list-exports

# 特定のエクスポートを検索
aws cloudformation list-exports \
  --query 'Exports[?Name==`MyVPCId`].Value' \
  --output text
```

## スタックドリフトの検出

### ドリフト検出の実行
```bash
# ドリフト検出を開始
DRIFT_ID=$(aws cloudformation detect-stack-drift \
  --stack-name my-stack \
  --query 'StackDriftDetectionId' \
  --output text)

echo "Drift detection started: $DRIFT_ID"

# 検出完了を待機
aws cloudformation wait stack-drift-detection-complete \
  --stack-drift-detection-id $DRIFT_ID

# 結果を表示
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id $DRIFT_ID
```

### ドリフトの詳細確認
```bash
# ドリフトしたリソースを表示
aws cloudformation describe-stack-resource-drifts \
  --stack-name my-stack \
  --stack-resource-drift-status-filters MODIFIED DELETED

# ドリフトの詳細を表示
aws cloudformation describe-stack-resource-drifts \
  --stack-name my-stack \
  --query 'StackResourceDrifts[].[LogicalResourceId,StackResourceDriftStatus,PropertyDifferences]' \
  --output json | jq
```

### 自動ドリフト検出スクリプト
```bash
#!/bin/bash
STACK_NAME="$1"

echo "Detecting drift for stack: $STACK_NAME"

# ドリフト検出開始
DRIFT_ID=$(aws cloudformation detect-stack-drift \
  --stack-name $STACK_NAME \
  --query 'StackDriftDetectionId' \
  --output text)

echo "Detection ID: $DRIFT_ID"
echo "Waiting for detection to complete..."

# 完了待機
aws cloudformation wait stack-drift-detection-complete \
  --stack-drift-detection-id $DRIFT_ID

# 結果取得
STATUS=$(aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id $DRIFT_ID \
  --query 'StackDriftStatus' \
  --output text)

echo "Stack Drift Status: $STATUS"

if [ "$STATUS" = "DRIFTED" ]; then
  echo ""
  echo "=== Drifted Resources ==="
  aws cloudformation describe-stack-resource-drifts \
    --stack-name $STACK_NAME \
    --stack-resource-drift-status-filters MODIFIED DELETED \
    --query 'StackResourceDrifts[].[LogicalResourceId,StackResourceDriftStatus]' \
    --output table
fi
```

## 実践的な例

### 完全なデプロイメントスクリプト
```bash
#!/bin/bash
STACK_NAME="my-application-stack"
TEMPLATE_FILE="template.yaml"
PARAMETERS_FILE="parameters.json"

echo "Deploying stack: $STACK_NAME"

# スタックが存在するか確認
if aws cloudformation describe-stacks --stack-name $STACK_NAME &>/dev/null; then
  echo "Stack exists. Updating..."
  
  # 更新
  aws cloudformation update-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters file://$PARAMETERS_FILE \
    --capabilities CAPABILITY_NAMED_IAM
  
  if [ $? -eq 0 ]; then
    echo "Waiting for update to complete..."
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
    echo "✅ Stack updated successfully!"
  else
    echo "❌ No updates to perform or update failed"
  fi
else
  echo "Stack does not exist. Creating..."
  
  # 作成
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters file://$PARAMETERS_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags \
      Key=Environment,Value=Production \
      Key=ManagedBy,Value=CloudFormation
  
  echo "Waiting for creation to complete..."
  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
  echo "✅ Stack created successfully!"
fi

# 出力を表示
echo ""
echo "=== Stack Outputs ==="
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs' \
  --output table
```

### ロールバックスクリプト
```bash
#!/bin/bash
STACK_NAME="$1"

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 <stack-name>"
  exit 1
fi

echo "Rolling back stack: $STACK_NAME"

# スタックの状態を確認
STATUS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].StackStatus' \
  --output text)

if [[ "$STATUS" == *"IN_PROGRESS"* ]]; then
  echo "Stack is currently updating. Canceling update..."
  aws cloudformation cancel-update-stack --stack-name $STACK_NAME
  
  echo "Waiting for rollback to complete..."
  aws cloudformation wait stack-rollback-complete --stack-name $STACK_NAME
else
  echo "Stack is not in a rollback-able state: $STATUS"
  exit 1
fi

echo "Rollback complete!"
```

### マルチスタックデプロイメント
```bash
#!/bin/bash
# 依存関係のある複数スタックをデプロイ

# 1. ネットワークスタック
echo "Deploying network stack..."
aws cloudformation create-stack \
  --stack-name network-stack \
  --template-body file://network.yaml \
  --parameters ParameterKey=Environment,ParameterValue=Production

aws cloudformation wait stack-create-complete --stack-name network-stack

# VPC IDを取得
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name network-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' \
  --output text)

echo "VPC Created: $VPC_ID"

# 2. データベーススタック
echo "Deploying database stack..."
aws cloudformation create-stack \
  --stack-name database-stack \
  --template-body file://database.yaml \
  --parameters \
    ParameterKey=VPCId,ParameterValue=$VPC_ID \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.micro

aws cloudformation wait stack-create-complete --stack-name database-stack

# エンドポイントを取得
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name database-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
  --output text)

echo "Database Endpoint: $DB_ENDPOINT"

# 3. アプリケーションスタック
echo "Deploying application stack..."
aws cloudformation create-stack \
  --stack-name application-stack \
  --template-body file://application.yaml \
  --parameters \
    ParameterKey=VPCId,ParameterValue=$VPC_ID \
    ParameterKey=DBEndpoint,ParameterValue=$DB_ENDPOINT

aws cloudformation wait stack-create-complete --stack-name application-stack

echo "All stacks deployed successfully!"
```

### スタック監視とアラート
```bash
#!/bin/bash
STACK_NAME="$1"
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:CloudFormationAlerts"

# スタック状態を監視
while true; do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null)
  
  if [ $? -ne 0 ]; then
    echo "Stack not found or error occurred"
    break
  fi
  
  echo "[$(date)] Stack status: $STATUS"
  
  # 失敗状態をチェック
  if [[ "$STATUS" == *"FAILED"* ]] || [[ "$STATUS" == *"ROLLBACK"* ]]; then
    # SNS通知
    aws sns publish \
      --topic-arn $SNS_TOPIC_ARN \
      --subject "CloudFormation Stack Alert" \
      --message "Stack $STACK_NAME is in $STATUS state"
    
    echo "Alert sent!"
    break
  fi
  
  # 完了状態をチェック
  if [[ "$STATUS" == *"COMPLETE"* ]] && [[ "$STATUS" != *"ROLLBACK"* ]]; then
    echo "Stack operation completed successfully!"
    break
  fi
  
  sleep 30
done
```

このドキュメントでは、CloudFormationスタックの包括的な操作方法を説明しました。実践的なスクリプト例を活用して、効率的なインフラ管理を実現してください。
