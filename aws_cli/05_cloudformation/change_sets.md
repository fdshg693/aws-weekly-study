# CloudFormation チェンジセット

## 目次
- [チェンジセットとは](#チェンジセットとは)
- [チェンジセットの作成](#チェンジセットの作成)
- [チェンジセットの確認](#チェンジセットの確認)
- [チェンジセットの実行](#チェンジセットの実行)
- [チェンジセットの削除](#チェンジセットの削除)
- [実践的な例](#実践的な例)

## チェンジセットとは

チェンジセット（Change Set）は、スタック更新前に変更内容をプレビューできる機能です。本番環境への変更を安全に実施するための重要な機能となります。

### 主な利点
- 変更内容の事前確認
- リソースの置き換えや削除の検出
- 安全な本番環境への適用
- レビュープロセスの実装

## チェンジセットの作成

### 基本的な作成
```bash
# シンプルなチェンジセット作成
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --template-body file://updated-template.yaml

# S3上のテンプレートから作成
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --template-url https://s3.amazonaws.com/my-bucket/updated-template.yaml
```

### パラメータ付きチェンジセット
```bash
# パラメータを変更
aws cloudformation create-change-set \
  --stack-name my-web-stack \
  --change-set-name scale-up-change \
  --use-previous-template \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.medium \
    ParameterKey=MinSize,ParameterValue=3 \
    ParameterKey=MaxSize,ParameterValue=10

# 一部パラメータは既存値を使用
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name update-instance-type \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.large \
    ParameterKey=KeyName,UsePreviousValue=true \
    ParameterKey=VpcId,UsePreviousValue=true
```

### 新しいスタック用のチェンジセット
```bash
# 新規スタック作成用のチェンジセット
aws cloudformation create-change-set \
  --stack-name new-stack \
  --change-set-name initial-creation \
  --change-set-type CREATE \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=Production \
  --capabilities CAPABILITY_NAMED_IAM
```

### タグとリソースタイプ指定
```bash
# タグを含むチェンジセット
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name tagged-changes \
  --template-body file://template.yaml \
  --tags \
    Key=Environment,Value=Production \
    Key=Version,Value=2.0

# 特定リソースタイプのみ含める
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name security-changes \
  --template-body file://template.yaml \
  --resource-types \
    AWS::EC2::SecurityGroup \
    AWS::IAM::Role \
    AWS::IAM::Policy
```

### インポート操作用のチェンジセット
```bash
# 既存リソースをインポート
cat > resources-to-import.json << 'EOF'
[
  {
    "ResourceType": "AWS::S3::Bucket",
    "LogicalResourceId": "MyExistingBucket",
    "ResourceIdentifier": {
      "BucketName": "my-existing-bucket-name"
    }
  }
]
EOF

aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name import-bucket \
  --change-set-type IMPORT \
  --resources-to-import file://resources-to-import.json \
  --template-body file://template-with-bucket.yaml
```

## チェンジセットの確認

### チェンジセット一覧
```bash
# スタックのすべてのチェンジセットを表示
aws cloudformation list-change-sets \
  --stack-name my-stack

# 簡潔な表示
aws cloudformation list-change-sets \
  --stack-name my-stack \
  --query 'Summaries[].[ChangeSetName,Status,CreationTime]' \
  --output table
```

### チェンジセットの詳細確認
```bash
# 詳細情報を取得
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set

# 変更内容のみ表示
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query 'Changes'

# 表形式で主要情報を表示
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query 'Changes[].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,ResourceType:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}' \
  --output table
```

### 変更の影響を分析
```bash
# 削除されるリソースを確認
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query 'Changes[?ResourceChange.Action==`Remove`]'

# 置き換えられるリソースを確認
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query 'Changes[?ResourceChange.Replacement==`True`]'

# 条件付き置き換えリソースを確認
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query 'Changes[?ResourceChange.Replacement==`Conditional`]'
```

### 詳細な変更レポート
```bash
# 完全な変更レポートを生成
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --query '{
    ChangeSetName: ChangeSetName,
    Status: Status,
    StatusReason: StatusReason,
    Changes: Changes[].{
      Action: ResourceChange.Action,
      LogicalId: ResourceChange.LogicalResourceId,
      ResourceType: ResourceChange.ResourceType,
      Replacement: ResourceChange.Replacement,
      Scope: ResourceChange.Scope,
      Details: ResourceChange.Details
    }
  }' \
  --output json | jq
```

### チェンジセット作成完了の待機
```bash
# チェンジセット作成
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --template-body file://template.yaml

# 作成完了を待機
aws cloudformation wait change-set-create-complete \
  --stack-name my-stack \
  --change-set-name my-change-set

echo "Change set is ready for review"
```

## チェンジセットの実行

### 基本的な実行
```bash
# チェンジセットを実行
aws cloudformation execute-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set

# 実行完了を待機
aws cloudformation wait stack-update-complete \
  --stack-name my-stack

echo "Changes applied successfully!"
```

### 無効化オプション付き実行
```bash
# ロールバック無効化で実行（デバッグ用）
aws cloudformation execute-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --disable-rollback
```

## チェンジセットの削除

### 基本的な削除
```bash
# チェンジセットを削除
aws cloudformation delete-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set

echo "Change set deleted"
```

### 古いチェンジセットの一括削除
```bash
#!/bin/bash
STACK_NAME="$1"

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 <stack-name>"
  exit 1
fi

echo "Deleting all change sets for stack: $STACK_NAME"

# すべてのチェンジセット名を取得
CHANGE_SETS=$(aws cloudformation list-change-sets \
  --stack-name $STACK_NAME \
  --query 'Summaries[].ChangeSetName' \
  --output text)

if [ -z "$CHANGE_SETS" ]; then
  echo "No change sets found"
  exit 0
fi

# 各チェンジセットを削除
for CS in $CHANGE_SETS; do
  echo "Deleting change set: $CS"
  aws cloudformation delete-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CS
done

echo "All change sets deleted"
```

## 実践的な例

### レビュー付きデプロイメントワークフロー
```bash
#!/bin/bash
STACK_NAME="my-production-stack"
TEMPLATE_FILE="template.yaml"
CHANGE_SET_NAME="deploy-$(date +%Y%m%d-%H%M%S)"

echo "=== Creating Change Set ==="
aws cloudformation create-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --template-body file://$TEMPLATE_FILE \
  --capabilities CAPABILITY_NAMED_IAM

echo "Waiting for change set creation..."
aws cloudformation wait change-set-create-complete \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME

echo ""
echo "=== Change Set Summary ==="
aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Changes[].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replace:ResourceChange.Replacement}' \
  --output table

echo ""
echo "=== Resources to be Replaced ==="
REPLACEMENTS=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Changes[?ResourceChange.Replacement==`True`].ResourceChange.LogicalResourceId' \
  --output text)

if [ -z "$REPLACEMENTS" ]; then
  echo "None"
else
  echo "$REPLACEMENTS"
fi

echo ""
read -p "Do you want to execute this change set? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
  echo "Executing change set..."
  aws cloudformation execute-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME
  
  echo "Waiting for stack update..."
  aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
  
  echo "✅ Deployment completed successfully!"
else
  echo "Deleting change set..."
  aws cloudformation delete-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME
  
  echo "Deployment cancelled"
fi
```

### 変更影響分析スクリプト
```bash
#!/bin/bash
STACK_NAME="$1"
CHANGE_SET_NAME="$2"

if [ -z "$STACK_NAME" ] || [ -z "$CHANGE_SET_NAME" ]; then
  echo "Usage: $0 <stack-name> <change-set-name>"
  exit 1
fi

echo "=== Change Set Impact Analysis ==="
echo "Stack: $STACK_NAME"
echo "Change Set: $CHANGE_SET_NAME"
echo ""

# ステータス確認
STATUS=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Status' \
  --output text)

echo "Status: $STATUS"

if [ "$STATUS" != "CREATE_COMPLETE" ]; then
  echo "❌ Change set is not ready for execution"
  exit 1
fi

# 統計情報
TOTAL=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'length(Changes)' \
  --output text)

ADD_COUNT=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'length(Changes[?ResourceChange.Action==`Add`])' \
  --output text)

MODIFY_COUNT=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'length(Changes[?ResourceChange.Action==`Modify`])' \
  --output text)

REMOVE_COUNT=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'length(Changes[?ResourceChange.Action==`Remove`])' \
  --output text)

REPLACE_COUNT=$(aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --query 'length(Changes[?ResourceChange.Replacement==`True`])' \
  --output text)

echo ""
echo "=== Statistics ==="
echo "Total changes: $TOTAL"
echo "Add: $ADD_COUNT"
echo "Modify: $MODIFY_COUNT"
echo "Remove: $REMOVE_COUNT"
echo "Replace: $REPLACE_COUNT"

# 危険な変更を警告
if [ "$REMOVE_COUNT" -gt 0 ] || [ "$REPLACE_COUNT" -gt 0 ]; then
  echo ""
  echo "⚠️  WARNING: This change set includes deletions or replacements!"
  
  if [ "$REMOVE_COUNT" -gt 0 ]; then
    echo ""
    echo "=== Resources to be Removed ==="
    aws cloudformation describe-change-set \
      --stack-name $STACK_NAME \
      --change-set-name $CHANGE_SET_NAME \
      --query 'Changes[?ResourceChange.Action==`Remove`].ResourceChange.[LogicalResourceId,ResourceType]' \
      --output table
  fi
  
  if [ "$REPLACE_COUNT" -gt 0 ]; then
    echo ""
    echo "=== Resources to be Replaced ==="
    aws cloudformation describe-change-set \
      --stack-name $STACK_NAME \
      --change-set-name $CHANGE_SET_NAME \
      --query 'Changes[?ResourceChange.Replacement==`True`].ResourceChange.[LogicalResourceId,ResourceType]' \
      --output table
  fi
else
  echo ""
  echo "✅ No dangerous changes detected"
fi
```

### CI/CDパイプライン統合
```bash
#!/bin/bash
# CI/CD用の自動チェンジセット作成・承認スクリプト

STACK_NAME="$1"
TEMPLATE_FILE="$2"
ENVIRONMENT="$3"

CHANGE_SET_NAME="cicd-${ENVIRONMENT}-$(git rev-parse --short HEAD)"

echo "Creating change set: $CHANGE_SET_NAME"

# チェンジセット作成
aws cloudformation create-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --template-body file://$TEMPLATE_FILE \
  --parameters file://params-${ENVIRONMENT}.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags \
    Key=Environment,Value=$ENVIRONMENT \
    Key=GitCommit,Value=$(git rev-parse HEAD) \
    Key=GitBranch,Value=$(git rev-parse --abbrev-ref HEAD)

# 作成完了待機
aws cloudformation wait change-set-create-complete \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME

# チェンジセット内容をJSONで保存
aws cloudformation describe-change-set \
  --stack-name $STACK_NAME \
  --change-set-name $CHANGE_SET_NAME \
  --output json > changeset-report.json

# 危険な変更をチェック
DANGEROUS=$(jq '[.Changes[] | select(.ResourceChange.Replacement == "True" or .ResourceChange.Action == "Remove")] | length' changeset-report.json)

if [ "$DANGEROUS" -gt 0 ]; then
  echo "⚠️  WARNING: Detected $DANGEROUS dangerous changes"
  
  if [ "$ENVIRONMENT" = "production" ]; then
    echo "❌ Manual approval required for production"
    echo "Change set created but not executed: $CHANGE_SET_NAME"
    exit 0
  fi
fi

# 自動実行（非本番環境のみ）
if [ "$ENVIRONMENT" != "production" ]; then
  echo "Auto-executing change set for $ENVIRONMENT"
  aws cloudformation execute-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME
  
  aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
  echo "✅ Deployment completed"
else
  echo "Awaiting manual approval for production deployment"
fi
```

### 複数環境への段階的デプロイ
```bash
#!/bin/bash
TEMPLATE_FILE="template.yaml"
CHANGE_SET_BASE_NAME="rolling-deploy-$(date +%Y%m%d-%H%M%S)"

ENVIRONMENTS=("dev" "staging" "production")

for ENV in "${ENVIRONMENTS[@]}"; do
  STACK_NAME="${ENV}-stack"
  CHANGE_SET_NAME="${CHANGE_SET_BASE_NAME}-${ENV}"
  
  echo ""
  echo "========================================="
  echo "Deploying to: $ENV"
  echo "========================================="
  
  # チェンジセット作成
  aws cloudformation create-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters file://params-${ENV}.json \
    --capabilities CAPABILITY_NAMED_IAM
  
  aws cloudformation wait change-set-create-complete \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME
  
  # 変更内容を表示
  echo "Changes for $ENV:"
  aws cloudformation describe-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME \
    --query 'Changes[].{Action:ResourceChange.Action,Resource:ResourceChange.LogicalResourceId}' \
    --output table
  
  # 本番環境は手動承認
  if [ "$ENV" = "production" ]; then
    read -p "Deploy to production? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Skipping production deployment"
      continue
    fi
  fi
  
  # 実行
  aws cloudformation execute-change-set \
    --stack-name $STACK_NAME \
    --change-set-name $CHANGE_SET_NAME
  
  aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
  
  echo "✅ $ENV deployment completed"
  
  # 次の環境へ進む前に一時停止
  if [ "$ENV" != "production" ]; then
    sleep 10
  fi
done

echo ""
echo "========================================="
echo "All environments deployed successfully!"
echo "========================================="
```

このドキュメントでは、CloudFormationチェンジセットの使い方を網羅的に説明しました。本番環境への安全なデプロイメントを実現するために、チェンジセットを積極的に活用してください。
