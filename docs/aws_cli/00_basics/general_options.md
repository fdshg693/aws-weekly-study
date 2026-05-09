# AWS CLI 汎用オプションガイド

すべての AWS CLI コマンドで使用できる汎用オプションについて詳しく解説します。

## 目次
- [--region](#--region)
- [--output](#--output)
- [--profile](#--profile)
- [--endpoint-url](#--endpoint-url)
- [--no-sign-request](#--no-sign-request)
- [--debug](#--debug)
- [--query](#--query)
- [--cli-input-json / --cli-input-yaml](#--cli-input-json----cli-input-yaml)
- [--generate-cli-skeleton](#--generate-cli-skeleton)
- [--no-cli-pager](#--no-cli-pager)
- [--color / --no-color](#--color----no-color)
- [--ca-bundle](#--ca-bundle)
- [--cli-read-timeout](#--cli-read-timeout)
- [--cli-connect-timeout](#--cli-connect-timeout)

---

## --region

コマンドを実行する AWS リージョンを指定します。

### 基本的な使用法

```bash
# 特定のリージョンでコマンドを実行
aws ec2 describe-instances --region ap-northeast-1
aws s3 ls --region us-west-2
aws lambda list-functions --region eu-west-1
```

### 複数リージョンでの実行

```bash
# すべてのリージョンの EC2 インスタンスを確認
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
    echo "=== Region: $region ==="
    aws ec2 describe-instances \
        --region $region \
        --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
        --output table
done
```

### リージョン別のリソース数を集計

```bash
#!/bin/bash
# 各リージョンの S3 バケット、EC2 インスタンス数を確認

echo "Region,S3Buckets,EC2Instances"

for region in ap-northeast-1 us-east-1 us-west-2 eu-west-1; do
    # S3 バケット数（S3 はグローバルサービスだが、リージョンを持つ）
    s3_count=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, '$region')]" \
        --output json | jq 'length')
    
    # EC2 インスタンス数
    ec2_count=$(aws ec2 describe-instances \
        --region $region \
        --query 'Reservations[].Instances[].InstanceId' \
        --output json | jq 'length')
    
    echo "$region,$s3_count,$ec2_count"
done
```

### グローバルサービスとリージョンサービス

```bash
# グローバルサービス（リージョン指定不要）
aws iam list-users
aws s3 ls
aws cloudfront list-distributions

# リージョンサービス（リージョン指定が必要または推奨）
aws ec2 describe-instances --region ap-northeast-1
aws rds describe-db-instances --region us-west-2
aws lambda list-functions --region eu-central-1
```

### 優先順位

リージョンは以下の順序で決定されます：

1. `--region` コマンドラインオプション
2. `AWS_DEFAULT_REGION` 環境変数
3. `AWS_REGION` 環境変数
4. プロファイルの設定（`~/.aws/config`）
5. インスタンスメタデータ（EC2 上で実行時）

```bash
# 優先順位のテスト
export AWS_DEFAULT_REGION=us-east-1
aws configure set region ap-northeast-1 --profile myprofile

# この場合、us-west-2 が使用される（コマンドライン優先）
aws ec2 describe-instances --region us-west-2 --profile myprofile
```

---

## --output

コマンドの出力形式を指定します。

### 出力形式の種類

#### 1. JSON（デフォルト）

```bash
# JSON 形式で出力
aws ec2 describe-instances --output json

# 整形された JSON
aws ec2 describe-instances --output json | jq '.'

# 特定のフィールドのみ抽出
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[].InstanceId'
```

**使用例:**
```json
{
    "Reservations": [
        {
            "Instances": [
                {
                    "InstanceId": "i-1234567890abcdef0",
                    "InstanceType": "t3.micro",
                    "State": {
                        "Name": "running"
                    }
                }
            ]
        }
    ]
}
```

#### 2. Table

```bash
# テーブル形式で出力（視覚的に見やすい）
aws ec2 describe-instances --output table

# クエリと組み合わせて特定のフィールドのみ表示
aws ec2 describe-instances \
    --output table \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PrivateIpAddress]'
```

**出力例:**
```
------------------------------------------------------------------
|                       DescribeInstances                        |
+----------------------+-------------+-----------+----------------+
|  i-1234567890abcdef0 |  t3.micro   |  running  |  10.0.1.100   |
|  i-0987654321fedcba0 |  t3.small   |  stopped  |  10.0.1.101   |
+----------------------+-------------+-----------+----------------+
```

#### 3. Text

```bash
# テキスト形式で出力（タブ区切り）
aws ec2 describe-instances --output text

# grep や awk との組み合わせ
aws ec2 describe-instances --output text | grep "running"
aws ec2 describe-instances --output text | awk '{print $1, $2}'

# 特定のフィールドのみ抽出
aws ec2 describe-instances \
    --output text \
    --query 'Reservations[].Instances[].[InstanceId,State.Name]'
```

**出力例:**
```
RESERVATIONS    123456789012    r-1234567890abcdef0
INSTANCES       0       x86_64  i-1234567890abcdef0     t3.micro        running
```

#### 4. YAML

```bash
# YAML 形式で出力
aws ec2 describe-instances --output yaml

# CloudFormation テンプレートとの親和性が高い
aws cloudformation describe-stacks --output yaml
```

**出力例:**
```yaml
Reservations:
- Instances:
  - InstanceId: i-1234567890abcdef0
    InstanceType: t3.micro
    State:
      Name: running
```

### 出力形式の使い分け

```bash
# スクリプトでの処理: JSON + jq
INSTANCE_ID=$(aws ec2 describe-instances \
    --output json \
    --query 'Reservations[0].Instances[0].InstanceId' \
    | jq -r '.')

# 手動確認: Table
aws ec2 describe-instances --output table

# シェルスクリプトでの解析: Text
aws ec2 describe-instances --output text | while read -r line; do
    echo "Processing: $line"
done

# ドキュメント化: YAML
aws cloudformation describe-stacks --output yaml > stacks.yaml
```

### 動的な出力形式の切り替え

```bash
#!/bin/bash
# 環境に応じて出力形式を変更

OUTPUT_FORMAT="json"

if [ -t 1 ]; then
    # 標準出力がターミナルの場合
    OUTPUT_FORMAT="table"
else
    # パイプやリダイレクトの場合
    OUTPUT_FORMAT="json"
fi

aws ec2 describe-instances --output $OUTPUT_FORMAT
```

---

## --profile

使用する AWS CLI プロファイルを指定します。

### 基本的な使用法

```bash
# 特定のプロファイルでコマンドを実行
aws s3 ls --profile production
aws ec2 describe-instances --profile development
aws lambda list-functions --profile staging
```

### プロファイルの一覧表示

```bash
# 設定されているプロファイルを確認
aws configure list-profiles

# 出力例:
# default
# production
# development
# staging
```

### プロファイルごとの認証情報確認

```bash
# 各プロファイルの認証情報を確認
for profile in $(aws configure list-profiles); do
    echo "=== Profile: $profile ==="
    aws sts get-caller-identity --profile $profile
    echo ""
done
```

### 環境変数との併用

```bash
# 環境変数でデフォルトプロファイルを設定
export AWS_PROFILE=production

# 環境変数が設定されている場合、--profile は不要
aws s3 ls

# 一時的に別のプロファイルを使用
aws s3 ls --profile development

# 環境変数を一時的に変更
AWS_PROFILE=staging aws lambda list-functions
```

### 複数プロファイルを使用したスクリプト

```bash
#!/bin/bash
# 複数の環境に同じ設定を適用

PROFILES=("development" "staging" "production")
BUCKET_NAME="my-config-bucket"

for profile in "${PROFILES[@]}"; do
    echo "Processing profile: $profile"
    
    # 各環境の S3 バケットに設定ファイルをアップロード
    aws s3 cp config.json s3://$BUCKET_NAME/$profile/ --profile $profile
    
    # 各環境の Lambda 関数を更新
    aws lambda update-function-configuration \
        --function-name my-function \
        --environment Variables={ENV=$profile} \
        --profile $profile
done
```

### プロファイルの切り替えを簡単にする

```bash
# エイリアスを作成（~/.bashrc または ~/.zshrc に追加）
alias awsp='export AWS_PROFILE='
alias awsp-list='aws configure list-profiles'
alias awsp-show='echo "Current profile: $AWS_PROFILE"'

# 使用例:
awsp production
awsp-show
# Current profile: production
```

**より高度な切り替え:**
```bash
# 関数を定義
awsprofile() {
    if [ -z "$1" ]; then
        echo "Current profile: $AWS_PROFILE"
        aws configure list-profiles
    else
        export AWS_PROFILE=$1
        echo "Switched to profile: $AWS_PROFILE"
        aws sts get-caller-identity
    fi
}

# 使用例:
awsprofile production
awsprofile development
awsprofile  # 現在のプロファイルを表示
```

---

## --endpoint-url

カスタムエンドポイント URL を指定します。LocalStack、MinIO、企業内プロキシなどで使用します。

### LocalStack での使用

```bash
# LocalStack のエンドポイント
LOCALSTACK_ENDPOINT="http://localhost:4566"

# S3 操作
aws s3 ls --endpoint-url $LOCALSTACK_ENDPOINT
aws s3 mb s3://test-bucket --endpoint-url $LOCALSTACK_ENDPOINT
aws s3 cp file.txt s3://test-bucket/ --endpoint-url $LOCALSTACK_ENDPOINT

# DynamoDB 操作
aws dynamodb list-tables --endpoint-url $LOCALSTACK_ENDPOINT
aws dynamodb create-table \
    --table-name Users \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url $LOCALSTACK_ENDPOINT

# Lambda 操作
aws lambda list-functions --endpoint-url $LOCALSTACK_ENDPOINT
```

### MinIO での使用

```bash
# MinIO（S3 互換ストレージ）
MINIO_ENDPOINT="http://localhost:9000"

aws s3 ls --endpoint-url $MINIO_ENDPOINT
aws s3 mb s3://my-bucket --endpoint-url $MINIO_ENDPOINT

# MinIO の認証情報を使用
aws s3 ls \
    --endpoint-url $MINIO_ENDPOINT \
    --profile minio
```

### Docker Compose での LocalStack 設定

```yaml
# docker-compose.yml
version: '3.8'

services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,dynamodb,lambda,sqs,sns
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - "./localstack-data:/tmp/localstack/data"
```

```bash
# LocalStack 起動
docker-compose up -d

# AWS CLI で接続
aws s3 ls --endpoint-url http://localhost:4566

# または環境変数で設定
export AWS_ENDPOINT_URL=http://localhost:4566
aws s3 ls
```

### エンドポイントのエイリアス作成

```bash
# ~/.bashrc または ~/.zshrc に追加
alias awslocal='aws --endpoint-url http://localhost:4566'
alias awsminio='aws --endpoint-url http://localhost:9000'

# 使用例:
awslocal s3 ls
awsminio s3 mb s3://test-bucket
```

### サービスごとの異なるエンドポイント

```bash
# S3 用エンドポイント
S3_ENDPOINT="http://localhost:9000"
# DynamoDB 用エンドポイント
DYNAMODB_ENDPOINT="http://localhost:8000"

# S3 操作
aws s3 ls --endpoint-url $S3_ENDPOINT

# DynamoDB 操作
aws dynamodb list-tables --endpoint-url $DYNAMODB_ENDPOINT
```

### 本番環境とローカル環境の切り替え

```bash
#!/bin/bash
# 環境に応じてエンドポイントを切り替え

ENVIRONMENT=${1:-local}

if [ "$ENVIRONMENT" = "local" ]; then
    ENDPOINT_URL="http://localhost:4566"
else
    ENDPOINT_URL=""  # 実際の AWS を使用
fi

# S3 バケット一覧
if [ -n "$ENDPOINT_URL" ]; then
    aws s3 ls --endpoint-url $ENDPOINT_URL
else
    aws s3 ls
fi
```

### VPC エンドポイントの使用

```bash
# VPC エンドポイント経由で S3 にアクセス
# （EC2 インスタンス内で実行）
aws s3 ls --endpoint-url https://bucket.vpce-1234567890abcdef0-12345678.s3.ap-northeast-1.vpce.amazonaws.com
```

---

## --no-sign-request

署名なしでリクエストを送信します。パブリックリソースにアクセスする際に使用します。

### パブリック S3 バケットへのアクセス

```bash
# AWS の公開データセットにアクセス
aws s3 ls s3://aws-publicdatasets/ --no-sign-request

# パブリックバケットからファイルをダウンロード
aws s3 cp s3://aws-publicdatasets/common-crawl/crawl-data/index.html . --no-sign-request

# パブリックバケットの同期
aws s3 sync s3://public-bucket/data/ ./local-data/ --no-sign-request
```

### 認証情報なしでの使用

```bash
# 認証情報が設定されていない環境で実行
# （認証情報がない場合でもパブリックリソースにアクセス可能）
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

aws s3 ls s3://opendata-bucket/ --no-sign-request
```

### パブリック ECR リポジトリへのアクセス

```bash
# パブリック ECR リポジトリを一覧表示
aws ecr-public describe-repositories --no-sign-request --region us-east-1

# パブリックイメージの情報を取得
aws ecr-public describe-images \
    --repository-name my-public-repo \
    --no-sign-request \
    --region us-east-1
```

### CloudFront のパブリックディストリビューション

```bash
# パブリックな CloudFront ディストリビューションの情報を取得
# （通常は署名が必要だが、特定の設定では不要）
aws cloudfront get-distribution --id E1234EXAMPLE --no-sign-request
```

### ユースケース

```bash
# 1. オープンデータの探索
aws s3 ls s3://noaa-goes16/ --no-sign-request
aws s3 ls s3://commoncrawl/ --no-sign-request

# 2. 公開ドキュメントのダウンロード
aws s3 cp s3://awsdocs-example-bucket/readme.txt . --no-sign-request

# 3. パブリック API のテスト
aws s3api head-object \
    --bucket public-bucket \
    --key public-file.txt \
    --no-sign-request
```

### 注意事項

```bash
# プライベートリソースには使用できない
aws s3 ls s3://private-bucket/ --no-sign-request
# エラー: An error occurred (403) when calling the ListObjectsV2 operation: Forbidden

# 正しくは認証情報を使用
aws s3 ls s3://private-bucket/
```

---

## --debug

デバッグ情報を出力します。問題のトラブルシューティングに使用します。

### 基本的なデバッグ

```bash
# デバッグモードでコマンドを実行
aws s3 ls --debug

# 出力内容:
# - API リクエストの詳細
# - HTTP ヘッダー
# - リクエスト/レスポンスボディ
# - 署名プロセス
# - リトライ処理
```

### デバッグ出力の活用

```bash
# デバッグ情報をファイルに保存
aws ec2 describe-instances --debug 2> debug.log

# 特定の情報のみを抽出
aws s3 ls --debug 2>&1 | grep "Request"
aws s3 ls --debug 2>&1 | grep "Response"
aws s3 ls --debug 2>&1 | grep "Authorization"
```

### API リクエストの確認

```bash
# API リクエストの詳細を確認
aws ec2 describe-instances --debug 2>&1 | grep -A 10 "Request"

# 出力例:
# 2024-11-15 10:00:00,123 - MainThread - botocore.endpoint - DEBUG - Making request for OperationModel(name=DescribeInstances) with params: {'url_path': '/', 'query_string': '', 'method': 'POST', 'headers': {...}, 'body': {...}}
```

### 署名プロセスのデバッグ

```bash
# 署名の計算過程を確認
aws s3 ls --debug 2>&1 | grep -i "signature"

# 出力例:
# StringToSign:
# AWS4-HMAC-SHA256
# 20241115T100000Z
# 20241115/ap-northeast-1/s3/aws4_request
# ...
```

### エラーのトラブルシューティング

```bash
# エラーが発生するコマンドをデバッグ
aws s3 cp file.txt s3://nonexistent-bucket/ --debug 2> error-debug.log

# エラーの詳細を確認
cat error-debug.log | grep -i "error"
cat error-debug.log | grep -i "exception"
```

### ネットワーク問題のデバッグ

```bash
# 接続タイムアウトの問題を調査
aws s3 ls --debug 2>&1 | grep -i "connect"
aws s3 ls --debug 2>&1 | grep -i "timeout"

# SSL/TLS の問題を調査
aws s3 ls --debug 2>&1 | grep -i "ssl"
aws s3 ls --debug 2>&1 | grep -i "certificate"
```

### リトライ処理の確認

```bash
# リトライの詳細を確認
aws dynamodb scan --table-name MyTable --debug 2>&1 | grep -i "retry"

# スロットリングの確認
aws dynamodb scan --table-name MyTable --debug 2>&1 | grep -i "throttl"
```

### デバッグログの整形

```bash
# Python スクリプトでデバッグログを解析
cat debug.log | python3 -c '
import sys
import re

for line in sys.stdin:
    if "Request" in line or "Response" in line or "Error" in line:
        print(line.strip())
'
```

### 本番環境でのデバッグ

```bash
#!/bin/bash
# 本番環境で安全にデバッグする

# デバッグ情報を収集
aws s3 ls --debug > debug_output.log 2>&1

# 機密情報をマスク
sed -i 's/AWS_ACCESS_KEY_ID=[^ ]*/AWS_ACCESS_KEY_ID=***MASKED***/g' debug_output.log
sed -i 's/Authorization: AWS4[^ ]*/Authorization: AWS4 ***MASKED***/g' debug_output.log

# サポートに送信
echo "デバッグログを作成しました: debug_output.log"
```

---

## --query

JMESPath を使用して出力をフィルタリングします。

### 基本的な構文

```bash
# トップレベルのフィールドを取得
aws ec2 describe-instances --query 'Reservations'

# ネストされたフィールドを取得
aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId'

# 配列の要素を取得
aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId'
```

### 配列の操作

```bash
# すべての要素を取得
aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId'

# 最初の要素
aws ec2 describe-instances --query 'Reservations[0].Instances[0]'

# 最後の要素
aws ec2 describe-instances --query 'Reservations[-1].Instances[-1]'

# 特定の範囲（スライス）
aws ec2 describe-instances --query 'Reservations[0:2].Instances[*]'
```

### フィルタリング

```bash
# 条件に一致する要素のみ取得
# running 状態のインスタンスのみ
aws ec2 describe-instances \
    --query "Reservations[*].Instances[?State.Name=='running'].InstanceId"

# 特定のインスタンスタイプのみ
aws ec2 describe-instances \
    --query "Reservations[*].Instances[?InstanceType=='t3.micro'].[InstanceId,PrivateIpAddress]"

# タグでフィルタリング
aws ec2 describe-instances \
    --query "Reservations[*].Instances[?Tags[?Key=='Environment' && Value=='production']].[InstanceId,PrivateIpAddress]"
```

### 複数フィールドの取得

```bash
# 複数のフィールドを配列で取得
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' \
    --output table

# オブジェクトとして取得
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name}' \
    --output table
```

### 集計関数

```bash
# 配列の長さ
aws ec2 describe-instances \
    --query 'length(Reservations[*].Instances[*])'

# 最大値
aws ec2 describe-volumes \
    --query 'max_by(Volumes, &Size).VolumeId'

# 最小値
aws ec2 describe-volumes \
    --query 'min_by(Volumes, &Size).VolumeId'

# ソート
aws ec2 describe-instances \
    --query 'sort_by(Reservations[*].Instances[*], &LaunchTime)[*].[InstanceId,LaunchTime]'
```

### 実用例

#### 1. EC2 インスタンスの情報を整形

```bash
# ID、タイプ、状態、プライベート IP を表示
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].{
        ID:InstanceId,
        Type:InstanceType,
        State:State.Name,
        PrivateIP:PrivateIpAddress,
        Name:Tags[?Key==`Name`].Value|[0]
    }' \
    --output table
```

#### 2. S3 バケットのサイズ順に表示

```bash
# S3 バケット一覧を取得
aws s3api list-buckets \
    --query 'Buckets[*].Name' \
    --output text | while read bucket; do
        size=$(aws s3 ls s3://$bucket --recursive --summarize | grep "Total Size" | awk '{print $3}')
        echo "$bucket: $size bytes"
    done | sort -t: -k2 -n
```

#### 3. Lambda 関数のランタイム別集計

```bash
# ランタイムごとの関数数を表示
aws lambda list-functions \
    --query 'Functions[*].Runtime' \
    --output text | tr '\t' '\n' | sort | uniq -c
```

#### 4. タグでフィルタリングして削除

```bash
# Environment=test タグを持つ EC2 インスタンスを停止
INSTANCE_IDS=$(aws ec2 describe-instances \
    --query "Reservations[*].Instances[?Tags[?Key=='Environment' && Value=='test']].InstanceId" \
    --output text)

if [ -n "$INSTANCE_IDS" ]; then
    aws ec2 stop-instances --instance-ids $INSTANCE_IDS
    echo "Stopped instances: $INSTANCE_IDS"
fi
```

#### 5. コスト分析用のデータ抽出

```bash
# アカウント内のすべての RDS インスタンスの詳細
aws rds describe-db-instances \
    --query 'DBInstances[*].{
        Name:DBInstanceIdentifier,
        Engine:Engine,
        Class:DBInstanceClass,
        Storage:AllocatedStorage,
        MultiAZ:MultiAZ,
        Status:DBInstanceStatus
    }' \
    --output table
```

### 複雑なクエリの例

```bash
# VPC ごとのサブネット数を集計
aws ec2 describe-subnets \
    --query 'Subnets[*].[VpcId,SubnetId]' \
    --output text | awk '{print $1}' | sort | uniq -c

# セキュリティグループで 0.0.0.0/0 を許可しているルールを検出
aws ec2 describe-security-groups \
    --query "SecurityGroups[?IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']]].{
        GroupId:GroupId,
        GroupName:GroupName,
        VpcId:VpcId
    }" \
    --output table
```

### JMESPath の高度な機能

```bash
# パイプ（|）を使用した連鎖
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*] | [0].{ID:InstanceId,Type:InstanceType}'

# マルチセレクトハッシュ
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].{id:InstanceId,type:InstanceType,state:State.Name}'

# フラット化
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[*].Value] | []'
```

---

## --cli-input-json / --cli-input-yaml

JSON または YAML ファイルから入力を読み込みます。

### 基本的な使用法

```bash
# JSON ファイルから入力
aws ec2 run-instances --cli-input-json file://instance-config.json

# YAML ファイルから入力
aws ec2 run-instances --cli-input-yaml file://instance-config.yaml

# 標準入力から読み込み
cat instance-config.json | aws ec2 run-instances --cli-input-json file:///dev/stdin
```

### スケルトンの生成（次のセクションを参照）

```bash
# スケルトンを生成してファイルに保存
aws ec2 run-instances --generate-cli-skeleton > ec2-template.json

# テンプレートを編集
vim ec2-template.json

# テンプレートから実行
aws ec2 run-instances --cli-input-json file://ec2-template.json
```

### EC2 インスタンス起動の例

```json
// instance-config.json
{
    "ImageId": "ami-0abcdef1234567890",
    "InstanceType": "t3.micro",
    "KeyName": "my-key-pair",
    "MinCount": 1,
    "MaxCount": 1,
    "SecurityGroupIds": ["sg-0123456789abcdef0"],
    "SubnetId": "subnet-0123456789abcdef0",
    "TagSpecifications": [
        {
            "ResourceType": "instance",
            "Tags": [
                {"Key": "Name", "Value": "MyInstance"},
                {"Key": "Environment", "Value": "Production"}
            ]
        }
    ]
}
```

```bash
# インスタンスを起動
aws ec2 run-instances --cli-input-json file://instance-config.json
```

### Lambda 関数作成の例

```yaml
# lambda-function.yaml
FunctionName: my-function
Runtime: python3.11
Role: arn:aws:iam::123456789012:role/lambda-role
Handler: index.handler
Code:
  ZipFile: |
    def handler(event, context):
        return {'statusCode': 200, 'body': 'Hello World'}
Timeout: 30
MemorySize: 128
Environment:
  Variables:
    ENV: production
    DEBUG: "false"
```

```bash
# Lambda 関数を作成
aws lambda create-function --cli-input-yaml file://lambda-function.yaml
```

### S3 バケットポリシーの適用

```json
// bucket-policy.json
{
    "Bucket": "my-bucket",
    "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::my-bucket/*\"}]}"
}
```

```bash
aws s3api put-bucket-policy --cli-input-json file://bucket-policy.json
```

### 複数環境での使用

```bash
# 開発環境用
aws ec2 run-instances --cli-input-json file://dev-instance.json

# 本番環境用
aws ec2 run-instances --cli-input-json file://prod-instance.json
```

### 変数の置換

```bash
#!/bin/bash
# テンプレートの変数を置換

ENVIRONMENT="production"
INSTANCE_TYPE="t3.small"

# 変数を置換して一時ファイルを作成
cat instance-template.json | \
    sed "s/\${ENVIRONMENT}/$ENVIRONMENT/g" | \
    sed "s/\${INSTANCE_TYPE}/$INSTANCE_TYPE/g" \
    > instance-config.json

# 実行
aws ec2 run-instances --cli-input-json file://instance-config.json

# クリーンアップ
rm instance-config.json
```

### jq を使用した動的生成

```bash
# jq で JSON を生成
jq -n \
    --arg ami "ami-0abcdef1234567890" \
    --arg type "t3.micro" \
    --arg key "my-key" \
    '{
        ImageId: $ami,
        InstanceType: $type,
        KeyName: $key,
        MinCount: 1,
        MaxCount: 1
    }' | aws ec2 run-instances --cli-input-json file:///dev/stdin
```

---

## --generate-cli-skeleton

コマンドの入力テンプレート（スケルトン）を生成します。

### 基本的な使用法

```bash
# JSON スケルトンを生成
aws ec2 run-instances --generate-cli-skeleton

# YAML スケルトンを生成
aws ec2 run-instances --generate-cli-skeleton yaml-input

# ファイルに保存
aws ec2 run-instances --generate-cli-skeleton > ec2-template.json
aws lambda create-function --generate-cli-skeleton yaml-input > lambda-template.yaml
```

### 生成されるテンプレートの例

```json
// aws ec2 run-instances --generate-cli-skeleton
{
    "BlockDeviceMappings": [
        {
            "DeviceName": "",
            "VirtualName": "",
            "Ebs": {
                "DeleteOnTermination": true,
                "Iops": 0,
                "SnapshotId": "",
                "VolumeSize": 0,
                "VolumeType": "standard",
                "Encrypted": true,
                "KmsKeyId": ""
            },
            "NoDevice": ""
        }
    ],
    "ImageId": "",
    "InstanceType": "t1.micro",
    "KeyName": "",
    "MaxCount": 0,
    "MinCount": 0,
    // ... 他のフィールド
}
```

### スケルトンのカスタマイズ

```bash
# 1. スケルトンを生成
aws rds create-db-instance --generate-cli-skeleton > rds-template.json

# 2. 不要なフィールドを削除し、必要な値を設定
cat > rds-config.json <<EOF
{
    "DBInstanceIdentifier": "my-database",
    "DBInstanceClass": "db.t3.micro",
    "Engine": "postgres",
    "MasterUsername": "admin",
    "MasterUserPassword": "MyPassword123!",
    "AllocatedStorage": 20,
    "BackupRetentionPeriod": 7,
    "MultiAZ": false,
    "PubliclyAccessible": false
}
EOF

# 3. 実行
aws rds create-db-instance --cli-input-json file://rds-config.json
```

### 入力と出力のスケルトン

```bash
# 入力スケルトン（リクエストパラメータ）
aws ec2 describe-instances --generate-cli-skeleton input

# 出力スケルトン（レスポンス構造）
aws ec2 describe-instances --generate-cli-skeleton output

# 両方を生成
aws ec2 describe-instances --generate-cli-skeleton input > input.json
aws ec2 describe-instances --generate-cli-skeleton output > output.json
```

### 複雑なコマンドのテンプレート化

```bash
# CloudFormation スタックの作成
aws cloudformation create-stack --generate-cli-skeleton > cfn-template.json

# カスタマイズ
cat > cfn-config.json <<EOF
{
    "StackName": "my-stack",
    "TemplateBody": "$(cat template.yaml)",
    "Parameters": [
        {"ParameterKey": "Environment", "ParameterValue": "production"},
        {"ParameterKey": "InstanceType", "ParameterValue": "t3.micro"}
    ],
    "Capabilities": ["CAPABILITY_IAM"],
    "Tags": [
        {"Key": "Project", "Value": "MyProject"},
        {"Key": "Owner", "Value": "DevTeam"}
    ]
}
EOF

# 実行
aws cloudformation create-stack --cli-input-json file://cfn-config.json
```

### ドキュメント生成への活用

```bash
#!/bin/bash
# すべての EC2 コマンドのスケルトンを生成

COMMANDS=(
    "run-instances"
    "describe-instances"
    "start-instances"
    "stop-instances"
    "terminate-instances"
)

mkdir -p ec2-skeletons

for cmd in "${COMMANDS[@]}"; do
    echo "Generating skeleton for: $cmd"
    aws ec2 $cmd --generate-cli-skeleton > "ec2-skeletons/${cmd}.json"
done

echo "Skeletons generated in ec2-skeletons/"
```

---

## --no-cli-pager

ページャー（less など）を無効にします。

### 基本的な使用法

```bash
# ページャーなしで出力
aws ec2 describe-instances --no-cli-pager

# 環境変数で無効化
export AWS_PAGER=""
aws ec2 describe-instances

# 設定ファイルで無効化
aws configure set cli_pager ""
```

### ページャーが必要な場合と不要な場合

```bash
# ページャーが便利な場合（手動確認）
aws ec2 describe-instances  # 自動的に less が起動

# ページャーが不要な場合（スクリプト、パイプ）
aws ec2 describe-instances --no-cli-pager | jq '.Reservations[].Instances[].InstanceId'
aws s3 ls --no-cli-pager | grep "my-bucket"
```

### CI/CD での使用

```bash
#!/bin/bash
# CI/CD パイプラインでの使用

# ページャーを無効化（自動化環境では必須）
export AWS_PAGER=""

# または各コマンドで指定
aws s3 ls --no-cli-pager
aws ec2 describe-instances --no-cli-pager
aws lambda list-functions --no-cli-pager
```

### スクリプトでの使用

```bash
#!/bin/bash
# インスタンス ID を取得してループ処理

# ページャーを無効化
export AWS_PAGER=""

# すべてのインスタンス ID を取得
INSTANCE_IDS=$(aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

# 各インスタンスを処理
for id in $INSTANCE_IDS; do
    echo "Processing instance: $id"
    aws ec2 describe-instances --instance-ids $id --no-cli-pager
done
```

### カスタムページャーの使用

```bash
# デフォルトは less
aws ec2 describe-instances

# カスタムページャーを指定
export AWS_PAGER="more"
aws ec2 describe-instances

# バットマン（構文ハイライト付きページャー）
export AWS_PAGER="bat --paging=always"
aws ec2 describe-instances
```

---

## --color / --no-color

出力のカラー表示を制御します。

### 基本的な使用法

```bash
# カラー表示を有効化
aws ec2 describe-instances --color on

# カラー表示を無効化
aws ec2 describe-instances --no-color
# または
aws ec2 describe-instances --color off

# 自動判定（デフォルト）
aws ec2 describe-instances --color auto
```

### 環境変数での設定

```bash
# カラー表示を無効化
export AWS_CLI_COLOR=off
aws ec2 describe-instances

# カラー表示を有効化
export AWS_CLI_COLOR=on
aws ec2 describe-instances
```

### ログファイルへの出力

```bash
# ログファイルに出力する場合はカラーを無効化
aws ec2 describe-instances --no-color > instances.log

# パイプ処理でも無効化推奨
aws ec2 describe-instances --no-color | tee instances.log
```

### CI/CD での使用

```bash
#!/bin/bash
# CI/CD 環境ではカラーを無効化

export AWS_CLI_COLOR=off

aws s3 ls
aws ec2 describe-instances
```

---

## --ca-bundle

カスタム CA 証明書バンドルを指定します。企業のプロキシ環境で使用します。

### 基本的な使用法

```bash
# CA 証明書バンドルを指定
aws s3 ls --ca-bundle /path/to/ca-bundle.crt

# 環境変数で設定
export AWS_CA_BUNDLE=/path/to/ca-bundle.crt
aws s3 ls

# 設定ファイルで設定
aws configure set ca_bundle /path/to/ca-bundle.crt
```

### 企業プロキシ環境での設定

```bash
# プロキシ設定
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080

# CA 証明書の指定
export AWS_CA_BUNDLE=/etc/ssl/certs/company-ca-bundle.crt

# AWS CLI の実行
aws s3 ls
```

### 証明書の取得と設定

```bash
# サーバーから証明書を取得
openssl s_client -showcerts -connect s3.amazonaws.com:443 </dev/null 2>/dev/null | \
    openssl x509 -outform PEM > aws-cert.pem

# 証明書バンドルの作成
cat /etc/ssl/certs/ca-certificates.crt aws-cert.pem > custom-ca-bundle.crt

# 使用
aws s3 ls --ca-bundle custom-ca-bundle.crt
```

### 自己署名証明書の使用（開発環境）

```bash
# 自己署名証明書を信頼
aws s3 ls --endpoint-url https://localhost:4566 \
    --ca-bundle /path/to/self-signed.crt \
    --no-verify-ssl  # 注意: 本番環境では使用しないこと
```

---

## --cli-read-timeout

API レスポンスの読み取りタイムアウトを秒単位で指定します。

### 基本的な使用法

```bash
# 読み取りタイムアウトを60秒に設定
aws s3 cp large-file.zip s3://my-bucket/ --cli-read-timeout 60

# デフォルトは60秒
# 大きなファイルのアップロード/ダウンロードでは延長を推奨
aws s3 cp huge-file.iso s3://my-bucket/ --cli-read-timeout 300
```

### 設定ファイルでの設定

```bash
# プロファイルごとに設定
aws configure set cli_read_timeout 120 --profile production

# 確認
aws configure get cli_read_timeout --profile production
```

### 大容量ファイルの転送

```bash
# 10GB のファイルをアップロード（タイムアウトを延長）
aws s3 cp 10gb-file.zip s3://my-bucket/ \
    --cli-read-timeout 600 \
    --cli-connect-timeout 60
```

### Lambda の長時間実行

```bash
# 長時間実行される Lambda 関数の呼び出し
aws lambda invoke \
    --function-name long-running-function \
    --cli-read-timeout 900 \
    response.json
```

---

## --cli-connect-timeout

API への接続タイムアウトを秒単位で指定します。

### 基本的な使用法

```bash
# 接続タイムアウトを30秒に設定
aws ec2 describe-instances --cli-connect-timeout 30

# ネットワークが不安定な環境では延長を推奨
aws s3 ls --cli-connect-timeout 60
```

### 設定ファイルでの設定

```bash
# プロファイルごとに設定
aws configure set cli_connect_timeout 30 --profile production
```

### タイムアウトの組み合わせ

```bash
# 接続と読み取りの両方を設定
aws s3 cp large-file.zip s3://my-bucket/ \
    --cli-connect-timeout 60 \
    --cli-read-timeout 300
```

### リトライとの組み合わせ

```bash
# タイムアウトとリトライを設定
aws configure set cli_connect_timeout 30
aws configure set cli_read_timeout 60
aws configure set max_attempts 5
aws configure set retry_mode adaptive
```

---

## オプションの組み合わせ例

### 総合的な使用例

```bash
# すべてのオプションを組み合わせた例
aws ec2 describe-instances \
    --region ap-northeast-1 \
    --profile production \
    --output table \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' \
    --no-cli-pager \
    --color off \
    --cli-connect-timeout 30 \
    --cli-read-timeout 60

# LocalStack でのテスト
aws s3 ls \
    --endpoint-url http://localhost:4566 \
    --no-sign-request \
    --output json \
    --no-cli-pager \
    --debug
```

### スクリプトでの標準設定

```bash
#!/bin/bash
# AWS CLI スクリプトの標準設定

set -euo pipefail

# 環境変数
export AWS_REGION=${AWS_REGION:-ap-northeast-1}
export AWS_PROFILE=${AWS_PROFILE:-default}
export AWS_PAGER=""
export AWS_CLI_COLOR=off

# 共通オプション
AWS_OPTS=(
    --output json
    --no-cli-pager
    --cli-connect-timeout 30
    --cli-read-timeout 60
)

# 使用例
aws ec2 describe-instances "${AWS_OPTS[@]}"
aws s3 ls "${AWS_OPTS[@]}"
```

---

## まとめ

AWS CLI の汎用オプションを活用することで：

- **--region**: 複数リージョンでの柔軟な操作
- **--output**: 用途に応じた最適な出力形式
- **--profile**: 複数アカウント・環境の安全な管理
- **--endpoint-url**: ローカル開発とテストの効率化
- **--no-sign-request**: パブリックリソースへの簡単なアクセス
- **--debug**: 問題のトラブルシューティング
- **--query**: 必要な情報のみを効率的に抽出
- **--cli-input-json/yaml**: 再利用可能な設定の管理
- **--generate-cli-skeleton**: テンプレートベースの作業
- **--no-cli-pager**: 自動化環境での円滑な実行
- **--color**: 環境に応じた表示制御
- **--ca-bundle**: 企業環境での安全な通信
- **--cli-*-timeout**: ネットワーク状況に応じた調整

これらのオプションを適切に組み合わせることで、AWS CLI をより効果的に活用できます。

前のドキュメント: [configuration.md](configuration.md)
