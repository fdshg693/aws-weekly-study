# AWS CLI スケルトンとインプットJSON

## 目次
- [スケルトンとは](#スケルトンとは)
- [スケルトンの生成](#スケルトンの生成)
- [インプットJSONの使用](#インプットjsonの使用)
- [複雑なコマンドの簡略化](#複雑なコマンドの簡略化)
- [テンプレート化とバージョン管理](#テンプレート化とバージョン管理)
- [実践的な例](#実践的な例)

## スケルトンとは

スケルトン（skeleton）は、AWS CLIコマンドのパラメータ構造をJSON形式で生成する機能です。複雑なコマンドを構築する際に便利です。

### スケルトンの利点
- 複雑なパラメータ構造の理解
- 再利用可能なテンプレートの作成
- タイプミスの削減
- ドキュメントとして使用可能
- バージョン管理が容易

### 基本概念
```bash
# スケルトンを生成
aws <service> <command> --generate-cli-skeleton

# スケルトンをファイルに保存
aws <service> <command> --generate-cli-skeleton > skeleton.json

# スケルトンから実行
aws <service> <command> --cli-input-json file://skeleton.json
```

## スケルトンの生成

### 基本的な生成
```bash
# EC2インスタンス起動のスケルトン
aws ec2 run-instances --generate-cli-skeleton

# S3バケット作成のスケルトン
aws s3api create-bucket --generate-cli-skeleton

# Lambda関数作成のスケルトン
aws lambda create-function --generate-cli-skeleton

# CloudFormationスタック作成のスケルトン
aws cloudformation create-stack --generate-cli-skeleton
```

### 出力形式の指定
```bash
# JSON形式（デフォルト）
aws ec2 run-instances --generate-cli-skeleton

# YAML形式
aws ec2 run-instances --generate-cli-skeleton yaml-input

# ファイルに保存
aws ec2 run-instances --generate-cli-skeleton > run-instances-skeleton.json

# 整形して保存
aws ec2 run-instances --generate-cli-skeleton | jq '.' > run-instances-skeleton.json
```

### スケルトンの構造確認
```bash
# EC2インスタンス起動のスケルトン例
aws ec2 run-instances --generate-cli-skeleton | jq '.'

# 出力例：
# {
#   "BlockDeviceMappings": [
#     {
#       "DeviceName": "",
#       "VirtualName": "",
#       "Ebs": {
#         "DeleteOnTermination": true,
#         "Iops": 0,
#         "SnapshotId": "",
#         "VolumeSize": 0,
#         "VolumeType": "",
#         "Encrypted": true,
#         "KmsKeyId": ""
#       }
#     }
#   ],
#   "ImageId": "",
#   "InstanceType": "",
#   "KeyName": "",
#   "MinCount": 0,
#   "MaxCount": 0,
#   ...
# }
```

### 必須フィールドの確認
```bash
# スケルトンから必須フィールドを抽出
aws lambda create-function --generate-cli-skeleton | \
  jq 'keys[] as $k | select(has($k)) | {key: $k, required: true}'

# ヘルプから必須パラメータを確認
aws lambda create-function help | grep -A 5 "SYNOPSIS"
```

## インプットJSONの使用

### 基本的な使用
```bash
# スケルトンを編集
cat > create-instance.json << 'EOF'
{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "InstanceType": "t3.micro",
  "KeyName": "my-key-pair",
  "MinCount": 1,
  "MaxCount": 1,
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {
          "Key": "Name",
          "Value": "MyInstance"
        },
        {
          "Key": "Environment",
          "Value": "Development"
        }
      ]
    }
  ]
}
EOF

# インプットJSONからインスタンスを起動
aws ec2 run-instances --cli-input-json file://create-instance.json
```

### パラメータの上書き
```bash
# インプットJSONとコマンドラインオプションを組み合わせ
aws ec2 run-instances \
  --cli-input-json file://create-instance.json \
  --instance-type t3.small

# 注意：コマンドラインオプションが優先される
```

### 標準入力からの読み込み
```bash
# パイプから直接入力
echo '{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "InstanceType": "t3.micro",
  "MinCount": 1,
  "MaxCount": 1
}' | aws ec2 run-instances --cli-input-json file:///dev/stdin

# ヒアドキュメント
aws ec2 run-instances --cli-input-json file:///dev/stdin << 'EOF'
{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "InstanceType": "t3.micro",
  "MinCount": 1,
  "MaxCount": 1
}
EOF
```

### YAML入力
```bash
# YAML形式のインプットファイル
cat > create-instance.yaml << 'EOF'
ImageId: ami-0c55b159cbfafe1f0
InstanceType: t3.micro
KeyName: my-key-pair
MinCount: 1
MaxCount: 1
TagSpecifications:
  - ResourceType: instance
    Tags:
      - Key: Name
        Value: MyInstance
      - Key: Environment
        Value: Development
EOF

# YAML入力から実行
aws ec2 run-instances --cli-input-yaml file://create-instance.yaml
```

## 複雑なコマンドの簡略化

### Lambda関数の作成
```bash
# スケルトンを生成
aws lambda create-function --generate-cli-skeleton > lambda-skeleton.json

# 編集
cat > create-lambda.json << 'EOF'
{
  "FunctionName": "MyFunction",
  "Runtime": "python3.11",
  "Role": "arn:aws:iam::123456789012:role/lambda-role",
  "Handler": "index.handler",
  "Code": {
    "ZipFile": "..."
  },
  "Description": "My Lambda function",
  "Timeout": 30,
  "MemorySize": 256,
  "Environment": {
    "Variables": {
      "ENV": "production",
      "DEBUG": "false"
    }
  },
  "Tags": {
    "Project": "MyProject",
    "CostCenter": "Engineering"
  }
}
EOF

# Zipファイルを含めて実行
aws lambda create-function \
  --cli-input-json file://create-lambda.json \
  --zip-file fileb://function.zip
```

### セキュリティグループの作成
```bash
# 複雑なセキュリティグループルール
cat > security-group.json << 'EOF'
{
  "GroupName": "web-server-sg",
  "Description": "Security group for web servers",
  "VpcId": "vpc-12345678",
  "IpPermissions": [
    {
      "IpProtocol": "tcp",
      "FromPort": 80,
      "ToPort": 80,
      "IpRanges": [
        {
          "CidrIp": "0.0.0.0/0",
          "Description": "HTTP from anywhere"
        }
      ]
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 443,
      "ToPort": 443,
      "IpRanges": [
        {
          "CidrIp": "0.0.0.0/0",
          "Description": "HTTPS from anywhere"
        }
      ]
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 22,
      "ToPort": 22,
      "IpRanges": [
        {
          "CidrIp": "10.0.0.0/8",
          "Description": "SSH from internal network"
        }
      ]
    }
  ],
  "TagSpecifications": [
    {
      "ResourceType": "security-group",
      "Tags": [
        {
          "Key": "Name",
          "Value": "WebServerSG"
        }
      ]
    }
  ]
}
EOF

aws ec2 create-security-group --cli-input-json file://security-group.json
```

### Auto Scaling設定
```bash
# Auto Scalingグループの複雑な設定
cat > asg-config.json << 'EOF'
{
  "AutoScalingGroupName": "my-asg",
  "LaunchTemplate": {
    "LaunchTemplateId": "lt-1234567890abcdef0",
    "Version": "$Latest"
  },
  "MinSize": 2,
  "MaxSize": 10,
  "DesiredCapacity": 3,
  "DefaultCooldown": 300,
  "AvailabilityZones": [
    "ap-northeast-1a",
    "ap-northeast-1c"
  ],
  "HealthCheckType": "ELB",
  "HealthCheckGracePeriod": 300,
  "TargetGroupARNs": [
    "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/my-targets/1234567890abcdef"
  ],
  "Tags": [
    {
      "Key": "Name",
      "Value": "my-asg-instance",
      "PropagateAtLaunch": true
    },
    {
      "Key": "Environment",
      "Value": "Production",
      "PropagateAtLaunch": true
    }
  ]
}
EOF

aws autoscaling create-auto-scaling-group --cli-input-json file://asg-config.json
```

## テンプレート化とバージョン管理

### 環境別設定
```bash
# ベーステンプレート
cat > instance-base.json << 'EOF'
{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "KeyName": "my-key-pair",
  "MinCount": 1,
  "MaxCount": 1,
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": []
    }
  ]
}
EOF

# 環境別設定を生成
for ENV in dev staging production; do
  cat > instance-${ENV}.json << EOF
{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "InstanceType": "$([ "$ENV" = "production" ] && echo "t3.medium" || echo "t3.micro")",
  "KeyName": "my-key-pair",
  "MinCount": $([ "$ENV" = "production" ] && echo "2" || echo "1"),
  "MaxCount": $([ "$ENV" = "production" ] && echo "2" || echo "1"),
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "app-${ENV}"},
        {"Key": "Environment", "Value": "${ENV}"}
      ]
    }
  ]
}
EOF
done

# 使用
aws ec2 run-instances --cli-input-json file://instance-production.json
```

### 変数の置換
```bash
#!/bin/bash
# deploy-with-template.sh - テンプレートから環境別にデプロイ

TEMPLATE_FILE="instance-template.json"
ENVIRONMENT="$1"
INSTANCE_TYPE="$2"

if [ -z "$ENVIRONMENT" ] || [ -z "$INSTANCE_TYPE" ]; then
  echo "Usage: $0 <environment> <instance-type>"
  exit 1
fi

# テンプレートの変数を置換
jq \
  --arg env "$ENVIRONMENT" \
  --arg type "$INSTANCE_TYPE" \
  '.TagSpecifications[0].Tags += [{"Key": "Environment", "Value": $env}] |
   .InstanceType = $type' \
  "$TEMPLATE_FILE" > instance-config.json

# デプロイ
aws ec2 run-instances --cli-input-json file://instance-config.json

# クリーンアップ
rm instance-config.json
```

### Gitでのバージョン管理
```bash
# .gitignore に追加
cat >> .gitignore << 'EOF'
# AWS credentials
**/credentials
**/config

# Generated files
**/*-generated.json
**/*-output.json
EOF

# テンプレートをコミット
git add instance-template.json lambda-config.json
git commit -m "Add AWS CLI input templates"

# 環境別ブランチ
git checkout -b production
# production用の設定を編集
git add instance-production.json
git commit -m "Add production instance configuration"
```

## 実践的な例

### マルチリージョンデプロイ
```bash
#!/bin/bash
# multi-region-deploy.sh - 複数リージョンにデプロイ

BASE_CONFIG="lambda-base.json"
REGIONS=("us-east-1" "eu-west-1" "ap-northeast-1")

for REGION in "${REGIONS[@]}"; do
  echo "Deploying to $REGION..."
  
  # リージョン固有の設定を生成
  jq --arg region "$REGION" \
    '.FunctionName = "MyFunction-\($region)" |
     .Environment.Variables.REGION = $region' \
    "$BASE_CONFIG" > "lambda-${REGION}.json"
  
  # デプロイ
  aws lambda create-function \
    --region "$REGION" \
    --cli-input-json file://lambda-${REGION}.json \
    --zip-file fileb://function.zip
  
  echo "✅ Deployed to $REGION"
done

# クリーンアップ
rm lambda-*.json
```

### バッチ処理
```bash
#!/bin/bash
# batch-create-instances.sh - 複数インスタンスを一括作成

TEMPLATE="instance-template.json"
INSTANCES=(
  "web-server-1:t3.micro:10.0.1.10"
  "web-server-2:t3.micro:10.0.1.11"
  "app-server-1:t3.small:10.0.2.10"
  "db-server-1:t3.medium:10.0.3.10"
)

for INSTANCE in "${INSTANCES[@]}"; do
  IFS=':' read -r NAME TYPE IP <<< "$INSTANCE"
  
  echo "Creating instance: $NAME"
  
  # テンプレートをカスタマイズ
  jq \
    --arg name "$NAME" \
    --arg type "$TYPE" \
    --arg ip "$IP" \
    '.InstanceType = $type |
     .PrivateIpAddress = $ip |
     .TagSpecifications[0].Tags += [{"Key": "Name", "Value": $name}]' \
    "$TEMPLATE" > "instance-${NAME}.json"
  
  # インスタンス作成
  INSTANCE_ID=$(aws ec2 run-instances \
    --cli-input-json file://instance-${NAME}.json \
    --query 'Instances[0].InstanceId' \
    --output text)
  
  echo "  Created: $INSTANCE_ID"
  
  # クリーンアップ
  rm "instance-${NAME}.json"
done
```

### 設定の検証
```bash
#!/bin/bash
# validate-config.sh - 設定ファイルを検証

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ File not found: $CONFIG_FILE"
  exit 1
fi

echo "Validating: $CONFIG_FILE"

# JSON構文チェック
if ! jq '.' "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "❌ Invalid JSON syntax"
  exit 1
fi

echo "✅ JSON syntax valid"

# 必須フィールドチェック（例：EC2インスタンス）
REQUIRED_FIELDS=("ImageId" "InstanceType" "MinCount" "MaxCount")

for FIELD in "${REQUIRED_FIELDS[@]}"; do
  if ! jq -e ".$FIELD" "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "❌ Missing required field: $FIELD"
    exit 1
  fi
  echo "✅ Field present: $FIELD"
done

# 値の検証
INSTANCE_TYPE=$(jq -r '.InstanceType' "$CONFIG_FILE")
if [[ ! "$INSTANCE_TYPE" =~ ^t[23]\. ]]; then
  echo "⚠️  Warning: Unusual instance type: $INSTANCE_TYPE"
fi

echo ""
echo "✅ Validation passed"
```

### ドライラン機能
```bash
#!/bin/bash
# dry-run-deploy.sh - ドライランでデプロイをテスト

CONFIG_FILE="$1"
DRY_RUN="${2:-true}"

if [ "$DRY_RUN" = "true" ]; then
  echo "=== DRY RUN MODE ==="
  echo "Configuration:"
  jq '.' "$CONFIG_FILE"
  
  echo ""
  echo "Command that would be executed:"
  echo "aws ec2 run-instances --cli-input-json file://$CONFIG_FILE"
  
  # 実際にドライランAPI呼び出し
  if aws ec2 run-instances \
    --cli-input-json file://"$CONFIG_FILE" \
    --dry-run 2>&1 | grep -q "DryRunOperation"; then
    echo "✅ Dry run successful - configuration is valid"
  else
    echo "❌ Dry run failed - check configuration"
    exit 1
  fi
else
  echo "=== EXECUTING ==="
  aws ec2 run-instances --cli-input-json file://"$CONFIG_FILE"
fi
```

### 設定の差分確認
```bash
#!/bin/bash
# diff-configs.sh - 2つの設定ファイルを比較

CONFIG1="$1"
CONFIG2="$2"

if [ -z "$CONFIG1" ] || [ -z "$CONFIG2" ]; then
  echo "Usage: $0 <config1> <config2>"
  exit 1
fi

echo "Comparing configurations:"
echo "  $CONFIG1"
echo "  $CONFIG2"
echo ""

# JSONを正規化して比較
diff <(jq -S '.' "$CONFIG1") <(jq -S '.' "$CONFIG2")

if [ $? -eq 0 ]; then
  echo "✅ Configurations are identical"
else
  echo ""
  echo "Key differences:"
  diff <(jq -S 'keys' "$CONFIG1") <(jq -S 'keys' "$CONFIG2")
fi
```

### CI/CDパイプライン統合
```bash
#!/bin/bash
# cicd-deploy.sh - CI/CDパイプライン用デプロイスクリプト

set -e

ENVIRONMENT="$1"
CONFIG_DIR="configs"
CONFIG_FILE="${CONFIG_DIR}/instance-${ENVIRONMENT}.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Configuration not found: $CONFIG_FILE"
  exit 1
fi

echo "=== Deploying to $ENVIRONMENT ==="

# 1. 設定の検証
echo "Validating configuration..."
jq '.' "$CONFIG_FILE" > /dev/null

# 2. ドライラン
echo "Running dry-run..."
aws ec2 run-instances \
  --cli-input-json file://"$CONFIG_FILE" \
  --dry-run 2>&1 | grep -q "DryRunOperation"

# 3. 実行
echo "Creating instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --cli-input-json file://"$CONFIG_FILE" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance created: $INSTANCE_ID"

# 4. タグ付け（CI/CD情報）
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags \
    "Key=DeployedBy,Value=CI/CD" \
    "Key=GitCommit,Value=$(git rev-parse HEAD)" \
    "Key=GitBranch,Value=$(git rev-parse --abbrev-ref HEAD)"

# 5. 起動待機
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo "✅ Deployment completed: $INSTANCE_ID"
```

### 設定ジェネレータ
```bash
#!/bin/bash
# generate-configs.sh - インタラクティブに設定を生成

echo "AWS CLI Configuration Generator"
echo "================================"
echo ""

read -p "Service (ec2/lambda/rds): " SERVICE
read -p "Resource name: " RESOURCE_NAME
read -p "Environment (dev/staging/prod): " ENVIRONMENT

case $SERVICE in
  ec2)
    read -p "Instance type (t3.micro): " INSTANCE_TYPE
    INSTANCE_TYPE=${INSTANCE_TYPE:-t3.micro}
    
    read -p "AMI ID: " AMI_ID
    read -p "Key pair name: " KEY_NAME
    
    cat > "${RESOURCE_NAME}-${ENVIRONMENT}.json" << EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "$INSTANCE_TYPE",
  "KeyName": "$KEY_NAME",
  "MinCount": 1,
  "MaxCount": 1,
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "$RESOURCE_NAME"},
        {"Key": "Environment", "Value": "$ENVIRONMENT"}
      ]
    }
  ]
}
EOF
    ;;
    
  lambda)
    read -p "Runtime (python3.11): " RUNTIME
    RUNTIME=${RUNTIME:-python3.11}
    
    read -p "Handler (index.handler): " HANDLER
    HANDLER=${HANDLER:-index.handler}
    
    read -p "Role ARN: " ROLE_ARN
    
    cat > "${RESOURCE_NAME}-${ENVIRONMENT}.json" << EOF
{
  "FunctionName": "$RESOURCE_NAME",
  "Runtime": "$RUNTIME",
  "Role": "$ROLE_ARN",
  "Handler": "$HANDLER",
  "Code": {
    "ZipFile": "..."
  },
  "Environment": {
    "Variables": {
      "ENVIRONMENT": "$ENVIRONMENT"
    }
  }
}
EOF
    ;;
esac

echo ""
echo "✅ Configuration generated: ${RESOURCE_NAME}-${ENVIRONMENT}.json"
```

このドキュメントでは、AWS CLIのスケルトンとインプットJSON機能を詳しく説明しました。複雑なコマンドを効率的に管理し、再利用可能なテンプレートを作成してください。
