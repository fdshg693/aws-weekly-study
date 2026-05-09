# AWS CLI フィルタリング

## 目次
- [フィルタリングの概要](#フィルタリングの概要)
- [--queryオプション](#--queryオプション)
- [JMESPath基礎](#jmespath基礎)
- [--filtersオプション](#--filtersオプション)
- [複合フィルタリング](#複合フィルタリング)
- [実践的な例](#実践的な例)

## フィルタリングの概要

AWS CLIでは2つの主要なフィルタリング方法があります：

1. **--query** (クライアント側) - JMESPathを使用して出力をフィルタリング
2. **--filters** (サーバー側) - APIレベルでデータをフィルタリング

### 使い分け
```bash
# サーバー側フィルタリング（推奨：効率的）
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"

# クライアント側フィルタリング
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`]'

# 組み合わせ（最も効率的）
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]'
```

## --queryオプション

`--query`オプションはJMESPathを使用して、AWS CLIの出力を加工・フィルタリングします。

### 基本的な使用
```bash
# 特定フィールドのみ抽出
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId'

# 複数フィールドを抽出
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]'

# 名前付きフィールド（オブジェクト形式）
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}'
```

### 配列操作
```bash
# 最初の要素
aws s3api list-buckets \
  --query 'Buckets[0].Name'

# 最後の要素
aws s3api list-buckets \
  --query 'Buckets[-1].Name'

# 範囲指定
aws s3api list-buckets \
  --query 'Buckets[0:3].Name'

# すべての要素
aws s3api list-buckets \
  --query 'Buckets[*].Name'

# 配列のフラット化
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text
```

### フィルタ式
```bash
# 条件でフィルタリング
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`]'

# 複数条件（AND）
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running` && InstanceType==`t3.micro`]'

# 複数条件（OR）
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running` || State.Name==`stopped`]'

# 否定
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name!=`terminated`]'
```

### 比較演算子
```bash
# 等しい
aws cloudwatch get-metric-statistics \
  --query 'Datapoints[?Average==`100`]'

# 大なり・小なり
aws ec2 describe-volumes \
  --query 'Volumes[?Size>`100`]'

# 以上・以下
aws ec2 describe-volumes \
  --query 'Volumes[?Size>=`100`]'

# 範囲チェック
aws cloudwatch get-metric-statistics \
  --query 'Datapoints[?Average>=`50` && Average<=`100`]'
```

### 文字列操作
```bash
# 開始文字列チェック
aws s3api list-buckets \
  --query 'Buckets[?starts_with(Name, `prod-`)]'

# 終了文字列チェック
aws s3api list-buckets \
  --query 'Buckets[?ends_with(Name, `-backup`)]'

# 部分一致
aws s3api list-buckets \
  --query 'Buckets[?contains(Name, `log`)]'
```

### ソート
```bash
# 昇順ソート
aws s3api list-buckets \
  --query 'sort_by(Buckets, &CreationDate)[].{Name:Name,Created:CreationDate}'

# 降順ソート（reverseと組み合わせ）
aws s3api list-buckets \
  --query 'reverse(sort_by(Buckets, &CreationDate))[].Name'

# 複数フィールドでソート
aws ec2 describe-instances \
  --query 'sort_by(Reservations[].Instances[], &[InstanceType, LaunchTime])'
```

### 集計関数
```bash
# 長さ・カウント
aws ec2 describe-instances \
  --query 'length(Reservations[].Instances[])'

# 最大値
aws ec2 describe-volumes \
  --query 'max_by(Volumes, &Size).VolumeId'

# 最小値
aws ec2 describe-volumes \
  --query 'min_by(Volumes, &Size).VolumeId'

# 合計（カスタム計算が必要）
aws ec2 describe-volumes \
  --query 'Volumes[].Size' \
  --output text | awk '{s+=$1} END {print s}'
```

### パイプ処理
```bash
# 複数の処理をパイプで連結
aws ec2 describe-instances \
  --query 'Reservations[].Instances[] | [?State.Name==`running`] | [].{ID:InstanceId,Type:InstanceType}'

# フィルタ→ソート→選択
aws ec2 describe-instances \
  --query 'Reservations[].Instances[] | [?State.Name==`running`] | sort_by(@, &LaunchTime) | [0:5]'
```

### 射影（Projection）
```bash
# ネストされた配列をフラット化
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].Tags[]'

# 特定の値のみ抽出
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value | []'

# 複雑なネスト構造
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0]]'
```

## JMESPath基礎

### 基本構文
```bash
# ドット表記
aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId'

# 配列アクセス
aws ec2 describe-instances --query 'Reservations[0]'

# ワイルドカード
aws ec2 describe-instances --query 'Reservations[*].Instances[*]'

# スライス
aws s3api list-buckets --query 'Buckets[0:5]'
```

### 複雑なクエリ例
```bash
# タグから名前を取得
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], State.Name]' \
  --output table

# 複数条件とカスタムオブジェクト
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].{
    ID: InstanceId,
    Name: Tags[?Key==`Name`].Value | [0],
    Type: InstanceType,
    IP: PrivateIpAddress,
    AZ: Placement.AvailabilityZone
  }' \
  --output table

# ネストした配列の処理
aws ec2 describe-security-groups \
  --query 'SecurityGroups[].{
    GroupId: GroupId,
    GroupName: GroupName,
    IngressRules: IpPermissions[].{
      Protocol: IpProtocol,
      Port: FromPort,
      Sources: IpRanges[].CidrIp
    }
  }'
```

## --filtersオプション

`--filters`オプションはサーバー側でデータをフィルタリングし、ネットワーク転送量を削減します。

### 基本構文
```bash
# 単一フィルタ
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"

# 複数の値
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped"

# 複数のフィルタ（AND条件）
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=instance-type,Values=t3.micro,t3.small"
```

### EC2フィルタ例
```bash
# インスタンスタイプでフィルタ
aws ec2 describe-instances \
  --filters "Name=instance-type,Values=t3.micro"

# アベイラビリティゾーンでフィルタ
aws ec2 describe-instances \
  --filters "Name=availability-zone,Values=ap-northeast-1a"

# タグでフィルタ
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production"

# タグキーの存在チェック
aws ec2 describe-instances \
  --filters "Name=tag-key,Values=Environment"

# IPアドレスでフィルタ
aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=10.0.1.100"

# VPCでフィルタ
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=vpc-12345678"

# サブネットでフィルタ
aws ec2 describe-instances \
  --filters "Name=subnet-id,Values=subnet-12345678"
```

### ワイルドカード
```bash
# 前方一致
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-*"

# 任意の文字列
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*-prod-*"

# AMIのフィルタリング
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2"
```

### 日付フィルタ
```bash
# 起動時刻でフィルタ（ISO 8601形式）
aws ec2 describe-instances \
  --filters "Name=launch-time,Values=2024-01-01T00:00:00.000Z"

# S3オブジェクトの最終更新日
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[?LastModified>=`2024-01-01`]'
```

### その他のサービスでのフィルタ
```bash
# CloudWatch Logs
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/

# Lambda関数
aws lambda list-functions \
  --query 'Functions[?Runtime==`python3.11`]'

# RDS インスタンス
aws rds describe-db-instances \
  --query 'DBInstances[?Engine==`postgres`]'

# DynamoDB テーブル
aws dynamodb list-tables \
  --query 'TableNames[?starts_with(@, `prod-`)]'
```

## 複合フィルタリング

### --filtersと--queryの組み合わせ
```bash
# サーバー側で絞り込み→クライアント側で整形
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,PrivateIpAddress]' \
  --output table

# タグでフィルタ→特定フィールドのみ表示
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" \
  --query 'Reservations[].Instances[].{
    ID: InstanceId,
    Name: Tags[?Key==`Name`].Value | [0],
    Type: InstanceType
  }' \
  --output table
```

### 多段階フィルタリング
```bash
# 1. サーバー側で大まかにフィルタ
# 2. クライアント側で詳細フィルタ
# 3. ソート
# 4. 上位N件のみ取得

aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[] | 
           [?InstanceType==`t3.micro` || InstanceType==`t3.small`] | 
           sort_by(@, &LaunchTime) | 
           reverse(@) | 
           [0:10].{
             ID: InstanceId,
             Type: InstanceType,
             Launched: LaunchTime
           }' \
  --output table
```

### パフォーマンス最適化
```bash
# ❌ 非効率（すべてのデータを取得してからフィルタ）
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`]'

# ✅ 効率的（サーバー側でフィルタ）
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"

# ✅ 最適（サーバー側フィルタ + クライアント側整形）
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' \
  --output text
```

## 実践的な例

### 特定条件のリソース検索
```bash
#!/bin/bash
# find-instances.sh - 複雑な条件でインスタンスを検索

ENVIRONMENT="$1"
INSTANCE_TYPE="$2"

if [ -z "$ENVIRONMENT" ] || [ -z "$INSTANCE_TYPE" ]; then
  echo "Usage: $0 <environment> <instance-type>"
  exit 1
fi

aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=$ENVIRONMENT" \
    "Name=instance-type,Values=$INSTANCE_TYPE" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{
    ID: InstanceId,
    Name: Tags[?Key==`Name`].Value | [0],
    Type: InstanceType,
    IP: PrivateIpAddress,
    AZ: Placement.AvailabilityZone,
    Launched: LaunchTime
  }' \
  --output table
```

### コスト分析用データ抽出
```bash
#!/bin/bash
# extract-cost-data.sh - コスト分析用にリソース情報を抽出

OUTPUT_FILE="resources-$(date +%Y%m%d).csv"

# ヘッダー
echo "ResourceType,ResourceId,Name,Environment,InstanceType,State" > $OUTPUT_FILE

# EC2インスタンス
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[
    `EC2`,
    InstanceId,
    Tags[?Key==`Name`].Value | [0],
    Tags[?Key==`Environment`].Value | [0],
    InstanceType,
    State.Name
  ]' \
  --output text | tr '\t' ',' >> $OUTPUT_FILE

# RDSインスタンス
aws rds describe-db-instances \
  --query 'DBInstances[].[
    `RDS`,
    DBInstanceIdentifier,
    DBInstanceIdentifier,
    Engine,
    DBInstanceClass,
    DBInstanceStatus
  ]' \
  --output text | tr '\t' ',' >> $OUTPUT_FILE

# ELB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].[
    `ELB`,
    LoadBalancerArn,
    LoadBalancerName,
    `N/A`,
    Type,
    State.Code
  ]' \
  --output text | tr '\t' ',' >> $OUTPUT_FILE

echo "Cost data exported to: $OUTPUT_FILE"
```

### セキュリティ監査
```bash
#!/bin/bash
# security-audit.sh - セキュリティ設定を監査

echo "=== Security Audit Report ==="
echo "Generated: $(date)"
echo ""

# パブリックアクセス可能なセキュリティグループ
echo "1. Security Groups with 0.0.0.0/0 access:"
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{
    GroupId: GroupId,
    GroupName: GroupName,
    VpcId: VpcId
  }' \
  --output table

echo ""

# パブリックIPを持つインスタンス
echo "2. Instances with Public IP:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?PublicIpAddress!=null].{
    InstanceId: InstanceId,
    Name: Tags[?Key==`Name`].Value | [0],
    PublicIP: PublicIpAddress,
    PrivateIP: PrivateIpAddress
  }' \
  --output table

echo ""

# パブリックアクセス可能なS3バケット
echo "3. S3 Buckets (checking public access):"
aws s3api list-buckets --query 'Buckets[].Name' --output text | while read BUCKET; do
  POLICY=$(aws s3api get-bucket-policy-status \
    --bucket $BUCKET \
    --query 'PolicyStatus.IsPublic' \
    --output text 2>/dev/null)
  
  if [ "$POLICY" = "True" ]; then
    echo "  ⚠️  $BUCKET - Public access enabled"
  fi
done

echo ""

# 暗号化されていないEBSボリューム
echo "4. Unencrypted EBS Volumes:"
aws ec2 describe-volumes \
  --filters "Name=encrypted,Values=false" \
  --query 'Volumes[].{
    VolumeId: VolumeId,
    Size: Size,
    State: State,
    Encrypted: Encrypted
  }' \
  --output table
```

### リソースクリーンアップ
```bash
#!/bin/bash
# cleanup-old-resources.sh - 古いリソースを特定

DAYS_OLD=30
CUTOFF_DATE=$(date -u -v-${DAYS_OLD}d '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d "$DAYS_OLD days ago" '+%Y-%m-%dT%H:%M:%S')

echo "Finding resources older than $DAYS_OLD days (before $CUTOFF_DATE)"
echo ""

# 古いスナップショット
echo "=== Old EBS Snapshots ==="
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?StartTime<'$CUTOFF_DATE'].{
    ID: SnapshotId,
    Description: Description,
    StartTime: StartTime,
    Size: VolumeSize
  }" \
  --output table

echo ""

# 古いAMI
echo "=== Old AMIs ==="
aws ec2 describe-images \
  --owners self \
  --query "Images[?CreationDate<'$CUTOFF_DATE'].{
    ID: ImageId,
    Name: Name,
    CreationDate: CreationDate
  }" \
  --output table

echo ""

# 停止中のインスタンス
echo "=== Stopped Instances ==="
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=stopped" \
  --query "Reservations[].Instances[?LaunchTime<'$CUTOFF_DATE'].{
    ID: InstanceId,
    Name: Tags[?Key==\`Name\`].Value | [0],
    Type: InstanceType,
    LaunchTime: LaunchTime
  }" \
  --output table
```

### カスタムクエリビルダー
```bash
#!/bin/bash
# query-builder.sh - 対話的にクエリを構築

echo "AWS CLI Query Builder"
echo "====================="
echo ""

read -p "Service (ec2/s3/rds): " SERVICE
read -p "Resource type (instances/buckets/db-instances): " RESOURCE

case $SERVICE in
  ec2)
    case $RESOURCE in
      instances)
        echo "Available filters:"
        echo "  1. instance-state-name"
        echo "  2. instance-type"
        echo "  3. tag:Name"
        echo "  4. vpc-id"
        
        read -p "Select filter (1-4): " FILTER_CHOICE
        read -p "Filter value: " FILTER_VALUE
        
        case $FILTER_CHOICE in
          1) FILTER_NAME="instance-state-name" ;;
          2) FILTER_NAME="instance-type" ;;
          3) FILTER_NAME="tag:Name" ;;
          4) FILTER_NAME="vpc-id" ;;
        esac
        
        COMMAND="aws ec2 describe-instances --filters \"Name=$FILTER_NAME,Values=$FILTER_VALUE\" --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output table"
        
        echo ""
        echo "Generated command:"
        echo "$COMMAND"
        echo ""
        
        read -p "Execute? (y/n): " EXECUTE
        if [ "$EXECUTE" = "y" ]; then
          eval $COMMAND
        fi
        ;;
    esac
    ;;
esac
```

このドキュメントでは、AWS CLIのフィルタリング機能を包括的に説明しました。`--filters`でサーバー側フィルタリング、`--query`でクライアント側フィルタリングを適切に組み合わせて使用してください。
