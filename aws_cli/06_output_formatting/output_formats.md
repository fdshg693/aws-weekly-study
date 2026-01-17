# AWS CLI 出力フォーマット

## 目次
- [出力フォーマットの概要](#出力フォーマットの概要)
- [JSON形式](#json形式)
- [YAML形式](#yaml形式)
- [テキスト形式](#テキスト形式)
- [テーブル形式](#テーブル形式)
- [出力フォーマットの設定](#出力フォーマットの設定)
- [実践的な例](#実践的な例)

## 出力フォーマットの概要

AWS CLIは4つの出力フォーマットをサポートしています：
- **JSON** (デフォルト) - 構造化されたデータ、プログラム処理に最適
- **YAML** - 人間が読みやすい、設定ファイルに最適
- **Text** - タブ区切り、スクリプト処理に最適
- **Table** - 視覚的に見やすい、対話的な使用に最適

### フォーマット指定方法
```bash
# コマンドラインで指定
aws ec2 describe-instances --output json
aws ec2 describe-instances --output yaml
aws ec2 describe-instances --output text
aws ec2 describe-instances --output table
```

## JSON形式

JSONは最も汎用性の高いフォーマットで、すべてのデータ構造を完全に表現できます。

### 基本的な使用
```bash
# JSON出力（デフォルト）
aws ec2 describe-instances

# 明示的にJSON指定
aws ec2 describe-instances --output json

# 整形されたJSON
aws ec2 describe-instances --output json | jq '.'
```

### JSONの利点
```bash
# jqで簡単に処理
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[].InstanceId'

# 特定フィールドのみ抽出
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {InstanceId, State: .State.Name, Type: .InstanceType}'

# 条件でフィルタリング
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | select(.State.Name == "running")'
```

### JSON出力の保存
```bash
# ファイルに保存
aws ec2 describe-instances --output json > instances.json

# 複数コマンドの結果を統合
{
  echo '{'
  echo '"instances": '
  aws ec2 describe-instances --output json
  echo ','
  echo '"buckets": '
  aws s3api list-buckets --output json
  echo '}'
} | jq '.' > aws-resources.json
```

### プログラミング言語での利用
```bash
# Python
aws ec2 describe-instances --output json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data['Reservations']:
    for i in r['Instances']:
        print(f\"{i['InstanceId']}: {i['State']['Name']}\")
"

# Node.js
aws s3api list-buckets --output json | node -e "
const data = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
data.Buckets.forEach(b => console.log(\`\${b.Name}: \${b.CreationDate}\`));
"
```

## YAML形式

YAMLは人間が読みやすく、CloudFormationテンプレートなどでよく使われる形式です。

### 基本的な使用
```bash
# YAML形式で出力
aws ec2 describe-instances --output yaml

# セキュリティグループをYAMLで表示
aws ec2 describe-security-groups --output yaml

# S3バケット一覧をYAML形式で
aws s3api list-buckets --output yaml
```

### YAMLの特徴
```bash
# 階層構造が見やすい
aws cloudformation describe-stacks --stack-name my-stack --output yaml

# 設定ファイルとして保存
aws iam get-role --role-name MyRole --output yaml > role-config.yaml

# yqでYAMLを処理
aws ec2 describe-instances --output yaml | yq '.Reservations[].Instances[].InstanceId'
```

### YAML vs JSON
```bash
# 同じデータをJSONとYAMLで比較
echo "=== JSON ==="
aws s3api get-bucket-location --bucket my-bucket --output json

echo ""
echo "=== YAML ==="
aws s3api get-bucket-location --bucket my-bucket --output yaml
```

## テキスト形式

テキスト形式はタブ区切りで出力され、シェルスクリプトでの処理に最適です。

### 基本的な使用
```bash
# テキスト形式で出力
aws ec2 describe-instances --output text

# インスタンスID一覧を取得
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text

# 複数フィールドを取得
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
  --output text
```

### シェルスクリプトでの活用
```bash
# ループ処理
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | while read INSTANCE_ID; do
  echo "Processing instance: $INSTANCE_ID"
  aws ec2 describe-instance-status --instance-ids $INSTANCE_ID
done

# 配列に格納
INSTANCE_IDS=($(aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text))

echo "Found ${#INSTANCE_IDS[@]} instances"

# カウント
RUNNING_COUNT=$(aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' \
  --output text | wc -w)

echo "Running instances: $RUNNING_COUNT"
```

### テキスト処理
```bash
# awkで処理
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
  --output text | awk '{print "ID:", $1, "Type:", $2, "State:", $3}'

# cutで特定フィールドのみ
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' \
  --output text | cut -f1

# sortとuniq
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceType' \
  --output text | tr '\t' '\n' | sort | uniq -c
```

### CSV形式への変換
```bash
# ヘッダー付きCSV
echo "InstanceId,InstanceType,State"
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
  --output text | tr '\t' ','

# 完全なCSV作成スクリプト
#!/bin/bash
OUTPUT_FILE="instances.csv"

# ヘッダー
echo "InstanceId,InstanceType,State,PrivateIP,PublicIP" > $OUTPUT_FILE

# データ
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output text | tr '\t' ',' >> $OUTPUT_FILE

echo "CSV exported to: $OUTPUT_FILE"
```

## テーブル形式

テーブル形式は視覚的に見やすく、人間が読むのに最適です。

### 基本的な使用
```bash
# テーブル形式で出力
aws ec2 describe-instances --output table

# インスタンス一覧を見やすく表示
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PrivateIpAddress]' \
  --output table

# S3バケット一覧
aws s3api list-buckets \
  --query 'Buckets[].[Name,CreationDate]' \
  --output table
```

### カスタムヘッダー付きテーブル
```bash
# 名前付きフィールドでテーブル作成
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{
    ID: InstanceId,
    Type: InstanceType,
    State: State.Name,
    IP: PrivateIpAddress,
    AZ: Placement.AvailabilityZone
  }' \
  --output table

# セキュリティグループ情報
aws ec2 describe-security-groups \
  --query 'SecurityGroups[].{
    GroupId: GroupId,
    GroupName: GroupName,
    VpcId: VpcId,
    Description: Description
  }' \
  --output table
```

### ソート済みテーブル
```bash
# インスタンスタイプでソート
aws ec2 describe-instances \
  --query 'sort_by(Reservations[].Instances[], &InstanceType)[].{
    ID: InstanceId,
    Type: InstanceType,
    State: State.Name
  }' \
  --output table

# 作成日時でソート
aws s3api list-buckets \
  --query 'sort_by(Buckets, &CreationDate)[].{
    Name: Name,
    Created: CreationDate
  }' \
  --output table
```

### 集計テーブル
```bash
# インスタンスタイプ別カウント
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceType]' \
  --output text | sort | uniq -c | \
  awk 'BEGIN {print "Count\tInstanceType"} {print $1"\t"$2}' | column -t

# ステータス別集計
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].State.Name' \
  --output text | tr '\t' '\n' | sort | uniq -c
```

## 出力フォーマットの設定

### グローバル設定
```bash
# デフォルト出力形式を設定
aws configure set output json

# 確認
aws configure get output

# プロファイルごとに設定
aws configure set output yaml --profile production
aws configure set output table --profile development
```

### 設定ファイル
```bash
# ~/.aws/config を編集
cat >> ~/.aws/config << 'EOF'

[default]
output = json

[profile dev]
output = table

[profile prod]
output = json
EOF

# 環境変数で指定
export AWS_DEFAULT_OUTPUT=yaml
aws ec2 describe-instances

# 一時的な変更
AWS_DEFAULT_OUTPUT=table aws s3 ls
```

### コマンドエイリアス
```bash
# ~/.bashrc または ~/.zshrc に追加
alias awsj='aws --output json'
alias awsy='aws --output yaml'
alias awst='aws --output text'
alias awsT='aws --output table'

# 使用例
awsj ec2 describe-instances
awsT s3 ls
```

## 実践的な例

### マルチフォーマット出力スクリプト
```bash
#!/bin/bash
# multi-format-output.sh - 複数形式で情報を出力

COMMAND="$@"

if [ -z "$COMMAND" ]; then
  echo "Usage: $0 <aws-cli-command>"
  exit 1
fi

echo "=== JSON ==="
$COMMAND --output json | head -20

echo ""
echo "=== YAML ==="
$COMMAND --output yaml | head -20

echo ""
echo "=== Table ==="
$COMMAND --output table

echo ""
echo "=== Text ==="
$COMMAND --output text | head -10
```

### レポート生成
```bash
#!/bin/bash
# generate-report.sh - HTML形式のレポート生成

REPORT_FILE="aws-report.html"

cat > $REPORT_FILE << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>AWS Resources Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h2 { color: #232F3E; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #232F3E; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .timestamp { color: #666; font-size: 0.9em; }
  </style>
</head>
<body>
  <h1>AWS Resources Report</h1>
  <p class="timestamp">Generated: $(date)</p>
EOF

# EC2インスタンス
echo "  <h2>EC2 Instances</h2>" >> $REPORT_FILE
echo "  <table>" >> $REPORT_FILE
echo "    <tr><th>Instance ID</th><th>Type</th><th>State</th><th>Private IP</th></tr>" >> $REPORT_FILE

aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PrivateIpAddress]' \
  --output text | while read ID TYPE STATE IP; do
  echo "    <tr><td>$ID</td><td>$TYPE</td><td>$STATE</td><td>$IP</td></tr>" >> $REPORT_FILE
done

echo "  </table>" >> $REPORT_FILE

# S3バケット
echo "  <h2>S3 Buckets</h2>" >> $REPORT_FILE
echo "  <table>" >> $REPORT_FILE
echo "    <tr><th>Bucket Name</th><th>Creation Date</th></tr>" >> $REPORT_FILE

aws s3api list-buckets \
  --query 'Buckets[].[Name,CreationDate]' \
  --output text | while read NAME DATE; do
  echo "    <tr><td>$NAME</td><td>$DATE</td></tr>" >> $REPORT_FILE
done

echo "  </table>" >> $REPORT_FILE

cat >> $REPORT_FILE << 'EOF'
</body>
</html>
EOF

echo "Report generated: $REPORT_FILE"
open $REPORT_FILE  # macOS
```

### JSON/YAML相互変換
```bash
#!/bin/bash
# convert-format.sh - JSON/YAML形式を相互変換

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <input-file> <output-file>"
  exit 1
fi

# 入力ファイルの形式を判定
if [[ "$INPUT_FILE" =~ \.json$ ]]; then
  # JSON → YAML
  yq eval -P . "$INPUT_FILE" > "$OUTPUT_FILE"
  echo "Converted JSON to YAML: $OUTPUT_FILE"
elif [[ "$INPUT_FILE" =~ \.(yaml|yml)$ ]]; then
  # YAML → JSON
  yq eval -o=json . "$INPUT_FILE" > "$OUTPUT_FILE"
  echo "Converted YAML to JSON: $OUTPUT_FILE"
else
  echo "Unsupported file format"
  exit 1
fi
```

### 動的フォーマット選択
```bash
#!/bin/bash
# smart-output.sh - 状況に応じて最適なフォーマットを選択

COMMAND="$@"

# ターミナルかどうかチェック
if [ -t 1 ]; then
  # インタラクティブな使用 → テーブル形式
  FORMAT="table"
else
  # パイプやリダイレクト → JSON形式
  FORMAT="json"
fi

# 環境変数で上書き可能
FORMAT="${AWS_OUTPUT_FORMAT:-$FORMAT}"

echo "Using format: $FORMAT" >&2
$COMMAND --output $FORMAT
```

### 比較ビューア
```bash
#!/bin/bash
# compare-outputs.sh - 異なる形式で出力を比較

COMMAND="$@"
TEMP_DIR=$(mktemp -d)

echo "Generating outputs..."

# 各形式で出力
aws $COMMAND --output json > "$TEMP_DIR/output.json"
aws $COMMAND --output yaml > "$TEMP_DIR/output.yaml"
aws $COMMAND --output text > "$TEMP_DIR/output.text"
aws $COMMAND --output table > "$TEMP_DIR/output.table"

# ファイルサイズを表示
echo ""
echo "=== Output Sizes ==="
ls -lh "$TEMP_DIR" | tail -n +2 | awk '{print $9, $5}'

# 各形式の最初の部分を表示
echo ""
echo "=== JSON (first 10 lines) ==="
head -10 "$TEMP_DIR/output.json"

echo ""
echo "=== YAML (first 10 lines) ==="
head -10 "$TEMP_DIR/output.yaml"

echo ""
echo "=== Text (first 10 lines) ==="
head -10 "$TEMP_DIR/output.text"

echo ""
echo "=== Table ==="
cat "$TEMP_DIR/output.table"

# クリーンアップ
rm -rf "$TEMP_DIR"
```

このドキュメントでは、AWS CLIの出力フォーマットの使い方を詳しく説明しました。用途に応じて最適なフォーマットを選択して、効率的にAWSリソースを管理してください。
