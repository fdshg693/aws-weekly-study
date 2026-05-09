# AWS CLI ページネーション

## 目次
- [ページネーションとは](#ページネーションとは)
- [自動ページネーション](#自動ページネーション)
- [手動ページネーション](#手動ページネーション)
- [ページサイズの制御](#ページサイズの制御)
- [パフォーマンス最適化](#パフォーマンス最適化)
- [実践的な例](#実践的な例)

## ページネーションとは

多くのAWS APIは大量のデータを返す際、結果をページに分割します。AWS CLIはこれを自動的に処理しますが、手動で制御することも可能です。

### ページネーションが必要な理由
- APIレスポンスサイズの制限
- ネットワーク効率の向上
- メモリ使用量の削減
- レート制限の回避

### AWS CLIのページネーション動作
```bash
# デフォルト：自動的にすべてのページを取得
aws ec2 describe-instances

# 設定確認
aws configure get cli_pager
aws configure get max_items
aws configure get page_size
```

## 自動ページネーション

AWS CLIはデフォルトで自動ページネーションを行い、すべての結果を取得します。

### 基本的な動作
```bash
# すべてのS3オブジェクトを取得（自動ページネーション）
aws s3api list-objects-v2 --bucket my-bucket

# 大量のインスタンスを取得
aws ec2 describe-instances

# すべてのログストリームを取得
aws logs describe-log-streams --log-group-name /aws/lambda/my-function
```

### ページネーション設定の無効化
```bash
# ページネーション無効化（非推奨）
aws ec2 describe-instances --no-paginate

# 最初のページのみ取得
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --no-paginate
```

## 手動ページネーション

大量のデータを扱う場合、手動でページネーションを制御すると効率的です。

### --max-itemsオプション
```bash
# 最大100件まで取得
aws ec2 describe-instances --max-items 100

# 最大50件のS3オブジェクトを取得
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --max-items 50

# 最大10個のスタックを取得
aws cloudformation list-stacks --max-items 10
```

### 次のページを取得
```bash
# 最初のページを取得
aws ec2 describe-instances \
  --max-items 10 \
  --output json > page1.json

# NextTokenを取得
NEXT_TOKEN=$(jq -r '.NextToken' page1.json)

# 次のページを取得
aws ec2 describe-instances \
  --max-items 10 \
  --starting-token "$NEXT_TOKEN" \
  --output json > page2.json
```

### すべてのページを順次取得
```bash
#!/bin/bash
# paginate-all.sh - すべてのページを順次取得

BUCKET_NAME="$1"
NEXT_TOKEN=""
PAGE=1

while true; do
  echo "Fetching page $PAGE..."
  
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --output json)
  else
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  # 結果を処理
  echo "$RESULT" | jq -r '.Contents[]?.Key'
  
  # 次のトークンを取得
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  # トークンがなければ終了
  if [ -z "$NEXT_TOKEN" ]; then
    echo "All pages fetched"
    break
  fi
  
  PAGE=$((PAGE + 1))
  sleep 1  # レート制限対策
done
```

## ページサイズの制御

`--page-size`オプションで各APIリクエストのページサイズを制御できます。

### 基本的な使用
```bash
# 小さいページサイズで取得（デフォルトは1000）
aws ec2 describe-instances --page-size 10

# 大きいページサイズで取得
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --page-size 1000

# 設定ファイルでデフォルトを変更
aws configure set page_size 100
```

### --page-size vs --max-items
```bash
# --page-size: 各APIリクエストのサイズ（内部的な動作）
# --max-items: ユーザーが受け取る最大数（結果の制限）

# 例：最大100件を取得するが、内部的には10件ずつリクエスト
aws ec2 describe-instances \
  --max-items 100 \
  --page-size 10

# この場合、10回のAPIリクエストが発行される
```

### レート制限への対応
```bash
# 小さいページサイズでレート制限を回避
aws s3api list-objects-v2 \
  --bucket my-large-bucket \
  --page-size 100 \
  --max-items 10000

# タイムアウトエラーを回避
aws ec2 describe-instances \
  --page-size 50 \
  --max-items 1000
```

## パフォーマンス最適化

### 並列処理
```bash
#!/bin/bash
# parallel-pagination.sh - 複数バケットを並列でページネーション

BUCKETS=(bucket1 bucket2 bucket3 bucket4)

for BUCKET in "${BUCKETS[@]}"; do
  {
    echo "Processing $BUCKET..."
    aws s3api list-objects-v2 \
      --bucket "$BUCKET" \
      --query 'Contents[].Key' \
      --output text > "${BUCKET}.txt"
    echo "$BUCKET completed"
  } &
done

wait
echo "All buckets processed"
```

### メモリ効率的な処理
```bash
#!/bin/bash
# memory-efficient.sh - メモリ効率的にページネーション

BUCKET_NAME="$1"
NEXT_TOKEN=""

while true; do
  # 一度に少量ずつ処理
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 100 \
      --output json)
  else
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 100 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  # ストリーム処理（メモリに全データを保持しない）
  echo "$RESULT" | jq -r '.Contents[]? | "\(.Key),\(.Size),\(.LastModified)"' >> objects.csv
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
done
```

### 進捗表示
```bash
#!/bin/bash
# progress-pagination.sh - 進捗を表示しながらページネーション

BUCKET_NAME="$1"
NEXT_TOKEN=""
TOTAL_COUNT=0
PAGE=1

echo "Counting objects in $BUCKET_NAME..."

while true; do
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --output json)
  else
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  PAGE_COUNT=$(echo "$RESULT" | jq '.Contents | length')
  TOTAL_COUNT=$((TOTAL_COUNT + PAGE_COUNT))
  
  echo "Page $PAGE: $PAGE_COUNT objects (Total: $TOTAL_COUNT)"
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
  
  PAGE=$((PAGE + 1))
done

echo ""
echo "Final count: $TOTAL_COUNT objects"
```

## 実践的な例

### 大規模バケットの分析
```bash
#!/bin/bash
# analyze-large-bucket.sh - 大規模バケットを分析

BUCKET_NAME="$1"
OUTPUT_FILE="bucket-analysis.json"

echo "Analyzing bucket: $BUCKET_NAME"

NEXT_TOKEN=""
TOTAL_SIZE=0
TOTAL_COUNT=0
declare -A EXTENSION_COUNT

while true; do
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --output json)
  else
    RESULT=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET_NAME" \
      --max-items 1000 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  # サイズを集計
  PAGE_SIZE=$(echo "$RESULT" | jq '[.Contents[]?.Size] | add // 0')
  TOTAL_SIZE=$((TOTAL_SIZE + PAGE_SIZE))
  
  # ファイル数をカウント
  PAGE_COUNT=$(echo "$RESULT" | jq '.Contents | length')
  TOTAL_COUNT=$((TOTAL_COUNT + PAGE_COUNT))
  
  # 拡張子別カウント
  echo "$RESULT" | jq -r '.Contents[]?.Key' | while read KEY; do
    EXT="${KEY##*.}"
    EXTENSION_COUNT[$EXT]=$((${EXTENSION_COUNT[$EXT]:-0} + 1))
  done
  
  echo "Processed $TOTAL_COUNT objects..."
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
  
  sleep 0.5
done

# 結果をJSON形式で出力
cat > $OUTPUT_FILE << EOF
{
  "bucket": "$BUCKET_NAME",
  "total_objects": $TOTAL_COUNT,
  "total_size_bytes": $TOTAL_SIZE,
  "total_size_gb": $(echo "scale=2; $TOTAL_SIZE / 1024 / 1024 / 1024" | bc),
  "analyzed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
echo "Analysis complete: $OUTPUT_FILE"
cat $OUTPUT_FILE | jq '.'
```

### CloudWatch Logs のエクスポート
```bash
#!/bin/bash
# export-logs.sh - CloudWatch Logsを効率的にエクスポート

LOG_GROUP="$1"
OUTPUT_FILE="logs-export.txt"

echo "Exporting logs from: $LOG_GROUP"

NEXT_TOKEN=""
STREAM_COUNT=0

# すべてのログストリームを取得
while true; do
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws logs describe-log-streams \
      --log-group-name "$LOG_GROUP" \
      --order-by LastEventTime \
      --descending \
      --max-items 50 \
      --output json)
  else
    RESULT=$(aws logs describe-log-streams \
      --log-group-name "$LOG_GROUP" \
      --order-by LastEventTime \
      --descending \
      --max-items 50 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  # 各ログストリームからイベントを取得
  echo "$RESULT" | jq -r '.logStreams[]?.logStreamName' | while read STREAM_NAME; do
    echo "Processing stream: $STREAM_NAME"
    
    aws logs get-log-events \
      --log-group-name "$LOG_GROUP" \
      --log-stream-name "$STREAM_NAME" \
      --limit 100 \
      --output json | \
      jq -r '.events[] | "\(.timestamp | todateiso8601) \(.message)"' >> "$OUTPUT_FILE"
    
    STREAM_COUNT=$((STREAM_COUNT + 1))
  done
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
done

echo ""
echo "Exported $STREAM_COUNT streams to: $OUTPUT_FILE"
```

### DynamoDB テーブルスキャン
```bash
#!/bin/bash
# scan-dynamodb.sh - DynamoDBテーブルを効率的にスキャン

TABLE_NAME="$1"
OUTPUT_FILE="${TABLE_NAME}-export.json"

echo "Scanning table: $TABLE_NAME"

NEXT_TOKEN=""
ITEM_COUNT=0

echo "[" > "$OUTPUT_FILE"
FIRST_ITEM=true

while true; do
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(aws dynamodb scan \
      --table-name "$TABLE_NAME" \
      --max-items 100 \
      --output json)
  else
    RESULT=$(aws dynamodb scan \
      --table-name "$TABLE_NAME" \
      --max-items 100 \
      --starting-token "$NEXT_TOKEN" \
      --output json)
  fi
  
  # アイテムをファイルに追加
  echo "$RESULT" | jq -c '.Items[]?' | while read ITEM; do
    if [ "$FIRST_ITEM" = true ]; then
      echo "  $ITEM" >> "$OUTPUT_FILE"
      FIRST_ITEM=false
    else
      echo ", $ITEM" >> "$OUTPUT_FILE"
    fi
    ITEM_COUNT=$((ITEM_COUNT + 1))
  done
  
  echo "Scanned $ITEM_COUNT items..."
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
  
  sleep 0.1  # DynamoDBのレート制限対策
done

echo "]" >> "$OUTPUT_FILE"

echo ""
echo "Exported $ITEM_COUNT items to: $OUTPUT_FILE"
```

### 複数アカウントの集約
```bash
#!/bin/bash
# multi-account-pagination.sh - 複数アカウントからデータを集約

PROFILES=("account1" "account2" "account3")
OUTPUT_FILE="all-instances.json"

echo "{" > "$OUTPUT_FILE"
FIRST_PROFILE=true

for PROFILE in "${PROFILES[@]}"; do
  echo "Processing profile: $PROFILE"
  
  if [ "$FIRST_PROFILE" = false ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  FIRST_PROFILE=false
  
  echo "  \"$PROFILE\": {" >> "$OUTPUT_FILE"
  echo "    \"instances\": [" >> "$OUTPUT_FILE"
  
  NEXT_TOKEN=""
  FIRST_INSTANCE=true
  
  while true; do
    if [ -z "$NEXT_TOKEN" ]; then
      RESULT=$(aws ec2 describe-instances \
        --profile "$PROFILE" \
        --max-items 50 \
        --output json)
    else
      RESULT=$(aws ec2 describe-instances \
        --profile "$PROFILE" \
        --max-items 50 \
        --starting-token "$NEXT_TOKEN" \
        --output json)
    fi
    
    echo "$RESULT" | jq -c '.Reservations[].Instances[]?' | while read INSTANCE; do
      if [ "$FIRST_INSTANCE" = false ]; then
        echo "," >> "$OUTPUT_FILE"
      fi
      FIRST_INSTANCE=false
      echo "      $INSTANCE" >> "$OUTPUT_FILE"
    done
    
    NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
    
    if [ -z "$NEXT_TOKEN" ]; then
      break
    fi
  done
  
  echo "    ]" >> "$OUTPUT_FILE"
  echo "  }" >> "$OUTPUT_FILE"
done

echo "}" >> "$OUTPUT_FILE"

echo ""
echo "All accounts processed: $OUTPUT_FILE"
```

### ページネーション統計
```bash
#!/bin/bash
# pagination-stats.sh - ページネーションの統計を取得

COMMAND="$@"

echo "Analyzing pagination for: $COMMAND"
echo ""

START_TIME=$(date +%s)
PAGE_COUNT=0
ITEM_COUNT=0
NEXT_TOKEN=""

while true; do
  PAGE_COUNT=$((PAGE_COUNT + 1))
  
  if [ -z "$NEXT_TOKEN" ]; then
    RESULT=$(eval "$COMMAND --max-items 100 --output json")
  else
    RESULT=$(eval "$COMMAND --max-items 100 --starting-token '$NEXT_TOKEN' --output json")
  fi
  
  # アイテム数をカウント（コマンドによって異なるパスを試行）
  PAGE_ITEMS=$(echo "$RESULT" | jq -r '
    if .Reservations then [.Reservations[].Instances[]] | length
    elif .Contents then .Contents | length
    elif .Items then .Items | length
    elif .Stacks then .Stacks | length
    else 0
    end
  ')
  
  ITEM_COUNT=$((ITEM_COUNT + PAGE_ITEMS))
  
  echo "Page $PAGE_COUNT: $PAGE_ITEMS items (Total: $ITEM_COUNT)"
  
  NEXT_TOKEN=$(echo "$RESULT" | jq -r '.NextToken // empty')
  
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== Pagination Statistics ==="
echo "Total Pages: $PAGE_COUNT"
echo "Total Items: $ITEM_COUNT"
echo "Duration: ${DURATION}s"
echo "Avg Items/Page: $((ITEM_COUNT / PAGE_COUNT))"
echo "Avg Time/Page: $(echo "scale=2; $DURATION / $PAGE_COUNT" | bc)s"
```

このドキュメントでは、AWS CLIのページネーション機能を詳しく説明しました。大量のデータを効率的に処理するために、適切なページネーション戦略を選択してください。
