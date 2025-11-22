# AWS CLI スクリプティング

## 目次
- [スクリプティングの基礎](#スクリプティングの基礎)
- [エラーハンドリング](#エラーハンドリング)
- [ロギングと監査](#ロギングと監査)
- [並列処理](#並列処理)
- [セキュリティのベストプラクティス](#セキュリティのベストプラクティス)
- [実践的なスクリプト例](#実践的なスクリプト例)

## スクリプティングの基礎

### シェバンとベストプラクティス
```bash
#!/bin/bash
# スクリプトの基本構造

# エラー時に即座に終了
set -e

# 未定義変数の使用時にエラー
set -u

# パイプラインのエラーを検出
set -o pipefail

# デバッグモード（開発時のみ）
# set -x

# スクリプト情報
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_VERSION="1.0.0"

# 定数定義
readonly AWS_REGION="ap-northeast-1"
readonly LOG_FILE="/var/log/aws-script.log"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ヘルプ関数
usage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description:
  AWS CLI automation script

Options:
  -h, --help     Show this help message
  -v, --version  Show version
  -r, --region   AWS region (default: $AWS_REGION)

Examples:
  $SCRIPT_NAME --region us-east-1

EOF
  exit 0
}

# バージョン表示
version() {
  echo "$SCRIPT_NAME version $SCRIPT_VERSION"
  exit 0
}

# メイン処理
main() {
  echo "Starting script..."
  # 処理内容
}

# オプション解析
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -v|--version)
      version
      ;;
    -r|--region)
      AWS_REGION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# 実行
main "$@"
```

### 環境チェック
```bash
#!/bin/bash
# check-environment.sh - 実行環境をチェック

check_requirements() {
  echo "Checking requirements..."
  
  # AWS CLI インストール確認
  if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
  fi
  echo "✅ AWS CLI: $(aws --version)"
  
  # jq インストール確認
  if ! command -v jq &> /dev/null; then
    echo "⚠️  jq is not installed (optional but recommended)"
  else
    echo "✅ jq: $(jq --version)"
  fi
  
  # AWS認証情報確認
  if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    exit 1
  fi
  
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
  echo "✅ AWS Account: $ACCOUNT_ID"
  echo "✅ IAM Principal: $USER_ARN"
  
  # リージョン確認
  REGION=$(aws configure get region)
  if [ -z "$REGION" ]; then
    echo "⚠️  No default region configured"
    REGION="us-east-1"
  fi
  echo "✅ AWS Region: $REGION"
  
  echo ""
  echo "All requirements met!"
}

check_requirements
```

### 設定ファイルの読み込み
```bash
#!/bin/bash
# load-config.sh - 設定ファイルを読み込む

# 設定ファイル
CONFIG_FILE="${CONFIG_FILE:-config.env}"

# 設定ファイルの読み込み
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    echo "Loading config from: $CONFIG_FILE"
    
    # 安全な読み込み（シェルインジェクション対策）
    while IFS='=' read -r key value; do
      # コメントと空行をスキップ
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      
      # 前後の空白を削除
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      
      # クォートを削除
      value="${value%\"}"
      value="${value#\"}"
      
      # 変数をエクスポート
      export "$key=$value"
      echo "  $key=$value"
    done < "$CONFIG_FILE"
  else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "Using default values"
  fi
}

# 設定ファイル例を作成
cat > config.env << 'EOF'
# AWS Configuration
AWS_REGION=ap-northeast-1
AWS_PROFILE=default

# Application Settings
ENVIRONMENT=production
LOG_LEVEL=info
BACKUP_ENABLED=true

# Resource Tags
TAG_PROJECT=MyProject
TAG_OWNER=DevOps
EOF

load_config
```

## エラーハンドリング

### 基本的なエラーハンドリング
```bash
#!/bin/bash
# error-handling.sh - エラーハンドリングの例

# エラートラップ
trap 'error_handler $? $LINENO' ERR

error_handler() {
  local exit_code=$1
  local line_number=$2
  
  echo "❌ Error occurred in script at line $line_number"
  echo "   Exit code: $exit_code"
  
  # クリーンアップ処理
  cleanup
  
  exit $exit_code
}

# クリーンアップ関数
cleanup() {
  echo "Performing cleanup..."
  # 一時ファイルの削除など
  rm -f /tmp/aws-temp-*
}

# 終了時に必ずクリーンアップ
trap cleanup EXIT

# AWS CLI実行のラッパー
aws_safe() {
  local max_retries=3
  local retry_delay=5
  local attempt=1
  
  while [ $attempt -le $max_retries ]; do
    echo "Attempt $attempt/$max_retries: $@"
    
    if aws "$@"; then
      return 0
    else
      local exit_code=$?
      
      if [ $attempt -lt $max_retries ]; then
        echo "⚠️  Command failed, retrying in ${retry_delay}s..."
        sleep $retry_delay
        attempt=$((attempt + 1))
      else
        echo "❌ Command failed after $max_retries attempts"
        return $exit_code
      fi
    fi
  done
}

# 使用例
aws_safe ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'
```

### リトライロジック
```bash
#!/bin/bash
# retry-logic.sh - リトライ機能付き実行

retry_with_backoff() {
  local max_attempts=5
  local timeout=1
  local attempt=1
  local exit_code=0
  
  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    else
      exit_code=$?
    fi
    
    echo "Attempt $attempt failed. Exit code: $exit_code"
    
    if [ $attempt -lt $max_attempts ]; then
      echo "Retrying in ${timeout}s..."
      sleep $timeout
      timeout=$((timeout * 2))  # Exponential backoff
      attempt=$((attempt + 1))
    else
      echo "All attempts failed"
      return $exit_code
    fi
  done
}

# 使用例
retry_with_backoff aws s3 cp large-file.dat s3://my-bucket/
```

### エラーメッセージの改善
```bash
#!/bin/bash
# better-error-messages.sh - わかりやすいエラーメッセージ

create_instance() {
  local ami_id="$1"
  local instance_type="$2"
  
  echo "Creating EC2 instance..."
  echo "  AMI: $ami_id"
  echo "  Type: $instance_type"
  
  local output
  local exit_code
  
  output=$(aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$instance_type" \
    --count 1 2>&1)
  exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    echo "❌ Failed to create instance"
    echo ""
    
    # エラーの種類を判定して適切なメッセージを表示
    if echo "$output" | grep -q "InvalidAMIID.NotFound"; then
      echo "Error: AMI not found"
      echo "  The AMI '$ami_id' does not exist in this region"
      echo "  Please check:"
      echo "    - AMI ID is correct"
      echo "    - AMI exists in the current region"
    elif echo "$output" | grep -q "Unsupported"; then
      echo "Error: Unsupported instance type"
      echo "  The instance type '$instance_type' is not available"
      echo "  Available types: t3.micro, t3.small, t3.medium, ..."
    elif echo "$output" | grep -q "UnauthorizedOperation"; then
      echo "Error: Insufficient permissions"
      echo "  Your IAM user/role lacks ec2:RunInstances permission"
    else
      echo "Error details:"
      echo "$output"
    fi
    
    return $exit_code
  fi
  
  local instance_id=$(echo "$output" | jq -r '.Instances[0].InstanceId')
  echo "✅ Instance created: $instance_id"
}

create_instance "ami-0c55b159cbfafe1f0" "t3.micro"
```

## ロギングと監査

### ロギング関数
```bash
#!/bin/bash
# logging.sh - ロギング機能

# ログレベル
declare -A LOG_LEVELS=( [DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 )
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-INFO}

# ログファイル
LOG_FILE="${LOG_FILE:-/var/log/aws-script.log}"
LOG_TO_FILE=${LOG_TO_FILE:-true}
LOG_TO_CONSOLE=${LOG_TO_CONSOLE:-true}

# ログ関数
log() {
  local level=$1
  shift
  local message="$@"
  
  # ログレベルチェック
  if [ ${LOG_LEVELS[$level]} -lt ${LOG_LEVELS[$CURRENT_LOG_LEVEL]} ]; then
    return
  fi
  
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_message="[$timestamp] [$level] $message"
  
  # コンソール出力
  if [ "$LOG_TO_CONSOLE" = true ]; then
    case $level in
      ERROR)
        echo -e "${RED}${log_message}${NC}" >&2
        ;;
      WARN)
        echo -e "${YELLOW}${log_message}${NC}"
        ;;
      INFO)
        echo -e "${GREEN}${log_message}${NC}"
        ;;
      *)
        echo "$log_message"
        ;;
    esac
  fi
  
  # ファイル出力
  if [ "$LOG_TO_FILE" = true ]; then
    echo "$log_message" >> "$LOG_FILE"
  fi
}

# 便利関数
log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }

# 使用例
log_info "Starting deployment"
log_debug "Debug information: var=$var"
log_warn "This is a warning"
log_error "An error occurred"
```

### 監査ログ
```bash
#!/bin/bash
# audit-log.sh - 監査ログの記録

AUDIT_LOG_FILE="/var/log/aws-audit.log"

audit_log() {
  local action="$1"
  local resource="$2"
  local status="$3"
  local details="$4"
  
  local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local user=$(aws sts get-caller-identity --query Arn --output text)
  local account=$(aws sts get-caller-identity --query Account --output text)
  
  local audit_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg user "$user" \
    --arg account "$account" \
    --arg action "$action" \
    --arg resource "$resource" \
    --arg status "$status" \
    --arg details "$details" \
    '{
      timestamp: $ts,
      user: $user,
      account: $account,
      action: $action,
      resource: $resource,
      status: $status,
      details: $details
    }')
  
  echo "$audit_entry" >> "$AUDIT_LOG_FILE"
  
  # CloudWatch Logsへ送信（オプション）
  # aws logs put-log-events --log-group-name /aws/audit ...
}

# 使用例
create_instance_audited() {
  local ami_id="$1"
  
  audit_log "CREATE_INSTANCE" "$ami_id" "STARTED" "Creating EC2 instance"
  
  if instance_id=$(aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type t3.micro \
    --query 'Instances[0].InstanceId' \
    --output text); then
    
    audit_log "CREATE_INSTANCE" "$instance_id" "SUCCESS" "Instance created successfully"
    echo "$instance_id"
  else
    audit_log "CREATE_INSTANCE" "$ami_id" "FAILED" "Instance creation failed"
    return 1
  fi
}
```

## 並列処理

### 基本的な並列実行
```bash
#!/bin/bash
# parallel-execution.sh - 並列実行

process_region() {
  local region=$1
  
  echo "[$region] Processing..."
  
  # リージョンのリソースを処理
  local count=$(aws ec2 describe-instances \
    --region "$region" \
    --query 'length(Reservations[].Instances[])' \
    --output text)
  
  echo "[$region] Found $count instances"
}

# 並列実行
REGIONS=("us-east-1" "eu-west-1" "ap-northeast-1" "ap-southeast-1")

for region in "${REGIONS[@]}"; do
  process_region "$region" &
done

# すべての完了を待機
wait

echo "All regions processed"
```

### 並列実行の制限
```bash
#!/bin/bash
# parallel-with-limit.sh - 並列実行数の制限

MAX_PARALLEL=3
JOBS=()

# ジョブキューの管理
wait_for_slot() {
  while [ ${#JOBS[@]} -ge $MAX_PARALLEL ]; do
    # 完了したジョブを削除
    for i in "${!JOBS[@]}"; do
      if ! kill -0 ${JOBS[$i]} 2>/dev/null; then
        unset 'JOBS[$i]'
      fi
    done
    JOBS=("${JOBS[@]}")  # 配列を再構築
    
    if [ ${#JOBS[@]} -ge $MAX_PARALLEL ]; then
      sleep 1
    fi
  done
}

# タスク実行
process_task() {
  local task_id=$1
  echo "Processing task $task_id"
  sleep 5  # 実際の処理
  echo "Task $task_id completed"
}

# 並列実行（最大3つまで）
for i in {1..10}; do
  wait_for_slot
  process_task $i &
  JOBS+=($!)
done

# すべて完了を待機
wait

echo "All tasks completed"
```

### GNU Parallel の使用
```bash
#!/bin/bash
# gnu-parallel.sh - GNU Parallelを使用

# インストール確認
if ! command -v parallel &> /dev/null; then
  echo "Installing GNU Parallel..."
  brew install parallel  # macOS
  # sudo apt-get install parallel  # Ubuntu
fi

# 複数リージョンを並列処理
export -f process_region  # 関数をエクスポート

echo "us-east-1 eu-west-1 ap-northeast-1" | \
  parallel -j 3 process_region {}

# ファイルからの並列処理
cat regions.txt | parallel -j 5 'aws ec2 describe-instances --region {}'

# 進捗表示付き
seq 1 100 | parallel -j 10 --bar 'aws s3 cp file{}.txt s3://my-bucket/'
```

## セキュリティのベストプラクティス

### 認証情報の安全な管理
```bash
#!/bin/bash
# secure-credentials.sh - 認証情報の安全な管理

# ❌ 悪い例：ハードコード
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"  # 絶対にしない！

# ✅ 良い例：環境変数から読み込み
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"

# ✅ 良い例：IAMロールを使用（EC2/ECS/Lambda）
# 認証情報の指定不要

# ✅ 良い例：AWS Secrets Managerから取得
get_secret() {
  local secret_name=$1
  
  aws secretsmanager get-secret-value \
    --secret-id "$secret_name" \
    --query SecretString \
    --output text
}

DB_PASSWORD=$(get_secret "prod/db/password")

# ✅ 良い例：Systems Manager Parameter Storeから取得
get_parameter() {
  local parameter_name=$1
  
  aws ssm get-parameter \
    --name "$parameter_name" \
    --with-decryption \
    --query Parameter.Value \
    --output text
}

API_KEY=$(get_parameter "/myapp/api-key")
```

### インプットの検証
```bash
#!/bin/bash
# input-validation.sh - インプットの検証

validate_instance_id() {
  local instance_id=$1
  
  # フォーマットチェック
  if [[ ! "$instance_id" =~ ^i-[0-9a-f]{8,17}$ ]]; then
    echo "❌ Invalid instance ID format: $instance_id"
    return 1
  fi
  
  # 存在確認
  if ! aws ec2 describe-instances \
    --instance-ids "$instance_id" &>/dev/null; then
    echo "❌ Instance not found: $instance_id"
    return 1
  fi
  
  return 0
}

validate_s3_bucket() {
  local bucket_name=$1
  
  # 命名規則チェック
  if [[ ! "$bucket_name" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
    echo "❌ Invalid bucket name: $bucket_name"
    return 1
  fi
  
  # 存在確認
  if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
    echo "❌ Bucket not found or no access: $bucket_name"
    return 1
  fi
  
  return 0
}

# 使用例
if validate_instance_id "$INSTANCE_ID"; then
  echo "✅ Instance ID is valid"
fi

if validate_s3_bucket "$BUCKET_NAME"; then
  echo "✅ Bucket name is valid"
fi
```

### 最小権限の原則
```bash
#!/bin/bash
# least-privilege.sh - 必要な権限のみを確認

check_permissions() {
  local required_actions=(
    "ec2:DescribeInstances"
    "ec2:RunInstances"
    "s3:ListBucket"
    "s3:PutObject"
  )
  
  echo "Checking required permissions..."
  
  for action in "${required_actions[@]}"; do
    # 実際の権限チェックは複雑なため、
    # ドライランで確認
    echo "  Checking: $action"
  done
  
  # IAMシミュレータを使用（より正確）
  # aws iam simulate-principal-policy ...
}
```

## 実践的なスクリプト例

### バックアップ自動化
```bash
#!/bin/bash
# auto-backup.sh - 自動バックアップスクリプト

set -euo pipefail

# 設定
BACKUP_BUCKET="my-backups-$(aws sts get-caller-identity --query Account --output text)"
RETENTION_DAYS=30
LOG_FILE="/var/log/aws-backup.log"

# ロギング
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$LOG_FILE"
}

# EC2インスタンスのスナップショット作成
backup_ec2_instances() {
  log "Starting EC2 backup..."
  
  # 対象インスタンスを取得
  local instances=$(aws ec2 describe-instances \
    --filters "Name=tag:Backup,Values=true" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
  
  for instance_id in $instances; do
    log "  Backing up instance: $instance_id"
    
    # AMI作成
    local ami_id=$(aws ec2 create-image \
      --instance-id "$instance_id" \
      --name "backup-$instance_id-$(date +%Y%m%d-%H%M%S)" \
      --description "Automated backup" \
      --no-reboot \
      --query 'ImageId' \
      --output text)
    
    log "  Created AMI: $ami_id"
    
    # タグ付け
    aws ec2 create-tags \
      --resources "$ami_id" \
      --tags \
        "Key=Name,Value=AutoBackup" \
        "Key=InstanceId,Value=$instance_id" \
        "Key=CreatedAt,Value=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  done
}

# RDSスナップショット作成
backup_rds_instances() {
  log "Starting RDS backup..."
  
  local db_instances=$(aws rds describe-db-instances \
    --query 'DBInstances[].DBInstanceIdentifier' \
    --output text)
  
  for db_instance in $db_instances; do
    log "  Backing up RDS instance: $db_instance"
    
    local snapshot_id="$db_instance-$(date +%Y%m%d-%H%M%S)"
    
    aws rds create-db-snapshot \
      --db-instance-identifier "$db_instance" \
      --db-snapshot-identifier "$snapshot_id"
    
    log "  Created snapshot: $snapshot_id"
  done
}

# 古いバックアップの削除
cleanup_old_backups() {
  log "Cleaning up old backups..."
  
  local cutoff_date=$(date -u -d "$RETENTION_DAYS days ago" +%Y-%m-%d 2>/dev/null || \
                      date -u -v-${RETENTION_DAYS}d +%Y-%m-%d)
  
  # 古いAMIを削除
  local old_amis=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=tag:Name,Values=AutoBackup" \
    --query "Images[?CreationDate<'$cutoff_date'].ImageId" \
    --output text)
  
  for ami_id in $old_amis; do
    log "  Deregistering old AMI: $ami_id"
    aws ec2 deregister-image --image-id "$ami_id"
  done
  
  # 古いRDSスナップショットを削除
  local old_snapshots=$(aws rds describe-db-snapshots \
    --snapshot-type manual \
    --query "DBSnapshots[?SnapshotCreateTime<'$cutoff_date'].DBSnapshotIdentifier" \
    --output text)
  
  for snapshot_id in $old_snapshots; do
    log "  Deleting old RDS snapshot: $snapshot_id"
    aws rds delete-db-snapshot --db-snapshot-identifier "$snapshot_id"
  done
}

# メイン処理
main() {
  log "=== Backup job started ==="
  
  backup_ec2_instances
  backup_rds_instances
  cleanup_old_backups
  
  log "=== Backup job completed ==="
}

main "$@"
```

### コスト監視スクリプト
```bash
#!/bin/bash
# cost-monitor.sh - コスト監視とアラート

set -euo pipefail

# 設定
BUDGET_THRESHOLD=1000  # USD
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:cost-alerts"

# 現在のコストを取得
get_current_cost() {
  local start_date=$(date -u -d "$(date +%Y-%m-01)" +%Y-%m-%d)
  local end_date=$(date -u +%Y-%m-%d)
  
  aws ce get-cost-and-usage \
    --time-period Start="$start_date",End="$end_date" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
    --output text
}

# サービス別コストを取得
get_cost_by_service() {
  local start_date=$(date -u -d "$(date +%Y-%m-01)" +%Y-%m-%d)
  local end_date=$(date -u +%Y-%m-%d)
  
  aws ce get-cost-and-usage \
    --time-period Start="$start_date",End="$end_date" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[].[Keys[0],Metrics.UnblendedCost.Amount]' \
    --output text | \
    sort -k2 -rn | \
    head -10
}

# アラートを送信
send_alert() {
  local message="$1"
  
  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "AWS Cost Alert" \
    --message "$message"
}

# メイン処理
main() {
  echo "Checking AWS costs..."
  
  local current_cost=$(get_current_cost)
  local current_cost_int=${current_cost%.*}
  
  echo "Current month cost: \$$current_cost"
  
  if [ "$current_cost_int" -gt "$BUDGET_THRESHOLD" ]; then
    echo "⚠️  Budget threshold exceeded!"
    
    local top_services=$(get_cost_by_service)
    
    local alert_message=$(cat << EOF
AWS Cost Alert

Current month cost: \$$current_cost
Budget threshold: \$$BUDGET_THRESHOLD

Top 10 services by cost:
$top_services

Please review your AWS usage.
EOF
)
    
    send_alert "$alert_message"
  else
    echo "✅ Within budget"
  fi
  
  echo ""
  echo "Top services by cost:"
  get_cost_by_service
}

main "$@"
```

### リソースタグ付けスクリプト
```bash
#!/bin/bash
# tag-resources.sh - リソースに一括でタグを付ける

set -euo pipefail

# 設定
TAG_KEY="ManagedBy"
TAG_VALUE="Terraform"
DRY_RUN=false

# EC2インスタンスにタグ付け
tag_ec2_instances() {
  local instances=$(aws ec2 describe-instances \
    --filters "Name=tag-key,Values=!$TAG_KEY" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
  
  if [ -z "$instances" ]; then
    echo "No untagged EC2 instances found"
    return
  fi
  
  echo "Tagging EC2 instances..."
  
  for instance_id in $instances; do
    echo "  $instance_id"
    
    if [ "$DRY_RUN" = false ]; then
      aws ec2 create-tags \
        --resources "$instance_id" \
        --tags "Key=$TAG_KEY,Value=$TAG_VALUE"
    fi
  done
}

# S3バケットにタグ付け
tag_s3_buckets() {
  local buckets=$(aws s3api list-buckets \
    --query 'Buckets[].Name' \
    --output text)
  
  echo "Tagging S3 buckets..."
  
  for bucket in $buckets; do
    # 既存タグを確認
    if aws s3api get-bucket-tagging --bucket "$bucket" 2>/dev/null | \
       jq -e ".TagSet[] | select(.Key==\"$TAG_KEY\")" > /dev/null; then
      continue
    fi
    
    echo "  $bucket"
    
    if [ "$DRY_RUN" = false ]; then
      aws s3api put-bucket-tagging \
        --bucket "$bucket" \
        --tagging "TagSet=[{Key=$TAG_KEY,Value=$TAG_VALUE}]"
    fi
  done
}

# Lambda関数にタグ付け
tag_lambda_functions() {
  local functions=$(aws lambda list-functions \
    --query 'Functions[].FunctionName' \
    --output text)
  
  echo "Tagging Lambda functions..."
  
  for function in $functions; do
    local arn=$(aws lambda get-function \
      --function-name "$function" \
      --query 'Configuration.FunctionArn' \
      --output text)
    
    echo "  $function"
    
    if [ "$DRY_RUN" = false ]; then
      aws lambda tag-resource \
        --resource "$arn" \
        --tags "$TAG_KEY=$TAG_VALUE"
    fi
  done
}

# メイン処理
main() {
  if [ "$DRY_RUN" = true ]; then
    echo "=== DRY RUN MODE ==="
  fi
  
  tag_ec2_instances
  tag_s3_buckets
  tag_lambda_functions
  
  echo ""
  echo "✅ Tagging completed"
}

# オプション解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --tag-key)
      TAG_KEY="$2"
      shift 2
      ;;
    --tag-value)
      TAG_VALUE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

main "$@"
```

このドキュメントでは、AWS CLIを使った高度なスクリプティング技術を説明しました。これらのパターンを活用して、信頼性が高く保守しやすい自動化スクリプトを作成してください。
