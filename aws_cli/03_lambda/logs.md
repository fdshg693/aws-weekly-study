# Lambda ログ管理

AWS Lambda関数のログをCloudWatch Logs経由でアクセス、検索、分析するためのAWS CLIコマンドガイド。

## 目次
- [CloudWatch Logsの基本](#cloudwatch-logsの基本)
- [ロググループの操作](#ロググループの操作)
- [ログストリームの操作](#ログストリームの操作)
- [ログイベントの取得](#ログイベントの取得)
- [ログのフィルタリング](#ログのフィルタリング)
- [リアルタイムログ監視](#リアルタイムログ監視)
- [ログのダウンロード](#ログのダウンロード)
- [関数メトリクスの取得](#関数メトリクスの取得)
- [呼び出しの監視](#呼び出しの監視)
- [実践的な例](#実践的な例)

---

## CloudWatch Logsの基本

### Lambda関数とCloudWatch Logs

Lambda関数は実行時に自動的にCloudWatch Logsにログを送信します。

**ロググループ命名規則:**
```
/aws/lambda/<function-name>
```

**基本的なログ構造:**
```bash
# ロググループ: /aws/lambda/my-function
#   └── ログストリーム: 2025/11/15/[$LATEST]abc123...
#       └── ログイベント: 個々のログメッセージ
```

### ログの確認フロー

```bash
# 1. Lambda関数を実行
aws lambda invoke \
    --function-name my-function \
    --payload '{"test":"data"}' \
    response.json

# 2. ロググループを確認
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/my-function

# 3. 最新のログストリームを取得
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --order-by LastEventTime \
    --descending \
    --max-items 1

# 4. ログイベントを表示
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123"
```

---

## ロググループの操作

### ロググループの一覧表示

```bash
# すべてのロググループを表示
aws logs describe-log-groups

# Lambda関数のロググループのみを表示
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/

# 特定の関数のロググループを表示
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/my-function
```

### ロググループ情報の取得

```bash
# ロググループ名とサイズを表示
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/ \
    --query 'logGroups[*].[logGroupName,storedBytes]' \
    --output table

# 保存期間を含めて表示
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/ \
    --query 'logGroups[*].[logGroupName,retentionInDays,storedBytes]' \
    --output table
```

### ログ保存期間の設定

```bash
# 保存期間を7日に設定
aws logs put-retention-policy \
    --log-group-name /aws/lambda/my-function \
    --retention-in-days 7

# 利用可能な保存期間: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 
#                      365, 400, 545, 731, 1827, 3653

# 30日に設定
aws logs put-retention-policy \
    --log-group-name /aws/lambda/my-function \
    --retention-in-days 30

# 保存期間の無期限化（削除）
aws logs delete-retention-policy \
    --log-group-name /aws/lambda/my-function
```

### ロググループの削除

```bash
# ロググループを削除
aws logs delete-log-group \
    --log-group-name /aws/lambda/my-old-function

# 複数のロググループを削除
for group in function1 function2 function3; do
    aws logs delete-log-group \
        --log-group-name /aws/lambda/$group
    echo "削除完了: $group"
done
```

### ロググループの作成

```bash
# 手動でロググループを作成（通常は自動作成されます）
aws logs create-log-group \
    --log-group-name /aws/lambda/my-new-function

# タグ付きで作成
aws logs create-log-group \
    --log-group-name /aws/lambda/my-function \
    --tags Environment=production,Team=backend
```

---

## ログストリームの操作

### ログストリームの一覧表示

```bash
# すべてのログストリームを表示
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function

# 最新のログストリームを表示
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --order-by LastEventTime \
    --descending \
    --max-items 5
```

### ログストリーム名のフォーマット

```bash
# 通常のフォーマット:
# 2025/11/15/[$LATEST]abc123def456...
# 2025/11/15/[1]xyz789abc123...

# 日付でフィルタリング
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name-prefix "2025/11/15/"

# 特定のバージョンでフィルタリング
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name-prefix "2025/11/15/[\$LATEST]"
```

### ログストリーム情報の取得

```bash
# ストリーム名、最終更新時刻、サイズを表示
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --order-by LastEventTime \
    --descending \
    --query 'logStreams[*].[logStreamName,lastEventTime,storedBytes]' \
    --output table

# 最新のログストリーム名を取得
LATEST_STREAM=$(aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)

echo "最新のログストリーム: $LATEST_STREAM"
```

---

## ログイベントの取得

### 基本的なログ取得

```bash
# ログストリームからログイベントを取得
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123"

# メッセージのみを表示
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --query 'events[*].message' \
    --output text
```

### 時間範囲でフィルタリング

```bash
# エポック時間（ミリ秒）で指定
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --start-time $START_TIME \
    --end-time $END_TIME

# 直近30分のログを取得
START_TIME=$(date -u -d '30 minutes ago' +%s)000
END_TIME=$(date -u +%s)000

aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].[timestamp,message]' \
    --output table
```

### ページネーション

```bash
# 最初の100イベントを取得
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --limit 100

# 次のページを取得（nextForwardTokenを使用）
NEXT_TOKEN="..."  # 前回のレスポンスから取得

aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --next-token $NEXT_TOKEN
```

### ログの順序

```bash
# 新しいログから古いログへ（逆順）
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --start-from-head false

# 古いログから新しいログへ（順方向）
aws logs get-log-events \
    --log-group-name /aws/lambda/my-function \
    --log-stream-name "2025/11/15/[\$LATEST]abc123" \
    --start-from-head true
```

---

## ログのフィルタリング

### filter-log-eventsコマンド

```bash
# すべてのログストリームから検索
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function

# パターンでフィルタリング
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR"

# 複数のキーワード（OR条件）
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR WARN"

# 特定のフレーズ
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '"Connection failed"'
```

### 時間範囲でフィルタリング

```bash
# 直近1時間のエラーログを検索
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR" \
    --start-time $START_TIME \
    --end-time $END_TIME

# メッセージのみを表示
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text
```

### 高度なフィルタパターン

```bash
# JSON形式のログからフィルタリング
# 例: {"level":"ERROR","message":"Database connection failed"}
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '{ $.level = "ERROR" }'

# 複数の条件（AND条件）
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '{ $.level = "ERROR" && $.statusCode = 500 }'

# 数値の比較
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '{ $.duration > 1000 }'

# 存在チェック
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '{ $.error = * }'
```

### パターンマッチングの例

```bash
# エラー関連のログ
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "?ERROR ?Error ?exception ?Exception"

# HTTPステータスコード
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "?500 ?502 ?503 ?504"

# タイムアウトエラー
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "?timeout ?Timeout ?TIMEOUT"

# メモリエラー
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "?memory ?Memory ?OutOfMemory"
```

---

## リアルタイムログ監視

### tail-log-eventsコマンド（AWS CLI v2）

```bash
# リアルタイムでログをテール（最新から継続的に表示）
aws logs tail /aws/lambda/my-function

# フィルタパターンを適用してテール
aws logs tail /aws/lambda/my-function \
    --filter-pattern "ERROR"

# 開始時刻を指定
aws logs tail /aws/lambda/my-function \
    --since 1h

# フォーマットを指定
aws logs tail /aws/lambda/my-function \
    --format short
```

### スクリプトでの継続監視

```bash
#!/bin/bash
# watch-lambda-logs.sh

LOG_GROUP="/aws/lambda/my-function"
FILTER_PATTERN="${1:-ERROR}"  # デフォルトは"ERROR"

echo "ログ監視を開始: $LOG_GROUP"
echo "フィルタ: $FILTER_PATTERN"
echo "Ctrl+Cで終了"
echo "---"

# 開始時刻を設定
START_TIME=$(date -u +%s)000

while true; do
    # 最新のログを取得
    END_TIME=$(date -u +%s)000
    
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "$FILTER_PATTERN" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'events[*].[timestamp,message]' \
        --output text
    
    # 次回の開始時刻を更新
    START_TIME=$END_TIME
    
    # 5秒待機
    sleep 5
done
```

### 複数関数の同時監視

```bash
#!/bin/bash
# watch-multiple-functions.sh

FUNCTIONS=("function1" "function2" "function3")
FILTER_PATTERN="ERROR"

echo "複数関数のログ監視を開始"
echo "---"

START_TIME=$(date -u +%s)000

while true; do
    END_TIME=$(date -u +%s)000
    
    for FUNCTION in "${FUNCTIONS[@]}"; do
        LOG_GROUP="/aws/lambda/$FUNCTION"
        
        EVENTS=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --filter-pattern "$FILTER_PATTERN" \
            --start-time $START_TIME \
            --end-time $END_TIME \
            --query 'events[*].message' \
            --output text)
        
        if [ -n "$EVENTS" ]; then
            echo "[$FUNCTION] $(date)"
            echo "$EVENTS"
            echo "---"
        fi
    done
    
    START_TIME=$END_TIME
    sleep 5
done
```

---

## ログのダウンロード

### ログのエクスポート

```bash
#!/bin/bash
# export-lambda-logs.sh

LOG_GROUP="/aws/lambda/my-function"
OUTPUT_FILE="lambda-logs-$(date +%Y%m%d-%H%M%S).log"

echo "ログをエクスポート中: $LOG_GROUP"

# 過去24時間のログを取得
START_TIME=$(date -u -d '24 hours ago' +%s)000
END_TIME=$(date -u +%s)000

# すべてのログストリームから取得
aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].[timestamp,message]' \
    --output text > "$OUTPUT_FILE"

echo "エクスポート完了: $OUTPUT_FILE"
echo "サイズ: $(wc -l < "$OUTPUT_FILE") 行"
```

### 日付範囲でエクスポート

```bash
#!/bin/bash
# export-logs-by-date.sh

LOG_GROUP="/aws/lambda/my-function"
START_DATE="2025-11-14"
END_DATE="2025-11-15"
OUTPUT_FILE="logs-${START_DATE}_${END_DATE}.log"

echo "期間: $START_DATE から $END_DATE"

START_TIME=$(date -u -d "$START_DATE 00:00:00" +%s)000
END_TIME=$(date -u -d "$END_DATE 23:59:59" +%s)000

aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].[timestamp,logStreamName,message]' \
    --output text > "$OUTPUT_FILE"

echo "エクスポート完了: $OUTPUT_FILE"
```

### JSON形式でエクスポート

```bash
#!/bin/bash
# export-logs-json.sh

LOG_GROUP="/aws/lambda/my-function"
OUTPUT_FILE="lambda-logs.json"

START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --output json > "$OUTPUT_FILE"

echo "JSON形式でエクスポート完了: $OUTPUT_FILE"

# jqで整形
cat "$OUTPUT_FILE" | jq '.' > "${OUTPUT_FILE}.formatted"
echo "整形版: ${OUTPUT_FILE}.formatted"
```

### S3へのエクスポート

```bash
# CloudWatch LogsからS3へのエクスポートタスクを作成
TASK_NAME="lambda-logs-export-$(date +%Y%m%d-%H%M%S)"
S3_BUCKET="my-log-archive-bucket"
S3_PREFIX="lambda-logs/my-function/"

START_TIME=$(date -u -d '1 day ago' +%s)000
END_TIME=$(date -u +%s)000

TASK_ID=$(aws logs create-export-task \
    --log-group-name /aws/lambda/my-function \
    --from $START_TIME \
    --to $END_TIME \
    --destination $S3_BUCKET \
    --destination-prefix $S3_PREFIX \
    --task-name $TASK_NAME \
    --query 'taskId' \
    --output text)

echo "エクスポートタスク作成: $TASK_ID"

# タスクの状態を確認
aws logs describe-export-tasks \
    --task-id $TASK_ID \
    --query 'exportTasks[0].status' \
    --output text
```

---

## 関数メトリクスの取得

### Lambda基本メトリクス

```bash
# 呼び出し回数を取得
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# エラー回数を取得
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# スロットル回数を取得
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Throttles \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

### 実行時間メトリクス

```bash
# 実行時間の統計
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum,Minimum

# 同時実行数
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name ConcurrentExecutions \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Maximum
```

### メモリ使用量

```bash
# ログからメモリ使用量を抽出
LOG_GROUP="/aws/lambda/my-function"
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "Memory Size:" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text

# REPORTログから詳細を抽出
aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "REPORT RequestId:" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text
```

---

## 呼び出しの監視

### リクエストIDでトレース

```bash
# 特定のリクエストIDのログを検索
REQUEST_ID="abc123-def456-ghi789"

aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "$REQUEST_ID" \
    --query 'events[*].[timestamp,message]' \
    --output table
```

### エラーログの分析

```bash
#!/bin/bash
# analyze-errors.sh

LOG_GROUP="/aws/lambda/my-function"
START_TIME=$(date -u -d '24 hours ago' +%s)000
END_TIME=$(date -u +%s)000

echo "=== エラー分析 ==="
echo "期間: 過去24時間"
echo ""

# エラーログを取得
ERRORS=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "ERROR" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text)

# エラー数をカウント
ERROR_COUNT=$(echo "$ERRORS" | wc -l)
echo "総エラー数: $ERROR_COUNT"
echo ""

# エラータイプ別に集計
echo "=== エラータイプ別集計 ==="
echo "$ERRORS" | grep -o 'Error: [^"]*' | sort | uniq -c | sort -rn
echo ""

# タイムアウトエラーをカウント
TIMEOUT_COUNT=$(echo "$ERRORS" | grep -i "timeout" | wc -l)
echo "タイムアウトエラー: $TIMEOUT_COUNT"

# メモリエラーをカウント
MEMORY_COUNT=$(echo "$ERRORS" | grep -i "memory" | wc -l)
echo "メモリエラー: $MEMORY_COUNT"
```

### パフォーマンス分析

```bash
#!/bin/bash
# analyze-performance.sh

LOG_GROUP="/aws/lambda/my-function"
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

echo "=== パフォーマンス分析 ==="

# REPORTログを取得
REPORTS=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "REPORT RequestId:" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text)

# 実行時間を抽出
DURATIONS=$(echo "$REPORTS" | grep -o 'Duration: [0-9.]*' | awk '{print $2}')

# 統計を計算
if [ -n "$DURATIONS" ]; then
    COUNT=$(echo "$DURATIONS" | wc -l)
    AVG=$(echo "$DURATIONS" | awk '{sum+=$1} END {print sum/NR}')
    MIN=$(echo "$DURATIONS" | sort -n | head -1)
    MAX=$(echo "$DURATIONS" | sort -n | tail -1)
    
    echo "実行回数: $COUNT"
    echo "平均実行時間: ${AVG}ms"
    echo "最小実行時間: ${MIN}ms"
    echo "最大実行時間: ${MAX}ms"
else
    echo "データがありません"
fi

echo ""

# メモリ使用量を抽出
MEMORY_USED=$(echo "$REPORTS" | grep -o 'Memory Used: [0-9]*' | awk '{print $3}')

if [ -n "$MEMORY_USED" ]; then
    AVG_MEMORY=$(echo "$MEMORY_USED" | awk '{sum+=$1} END {print sum/NR}')
    MAX_MEMORY=$(echo "$MEMORY_USED" | sort -n | tail -1)
    
    echo "平均メモリ使用量: ${AVG_MEMORY}MB"
    echo "最大メモリ使用量: ${MAX_MEMORY}MB"
fi
```

### コールドスタートの検出

```bash
#!/bin/bash
# detect-cold-starts.sh

LOG_GROUP="/aws/lambda/my-function"
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

echo "=== コールドスタート分析 ==="

# INITログとREPORTログを取得
LOGS=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "?INIT_START ?REPORT" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].message' \
    --output text)

# コールドスタート回数をカウント
COLD_STARTS=$(echo "$LOGS" | grep "INIT_START" | wc -l)
TOTAL_INVOCATIONS=$(echo "$LOGS" | grep "REPORT RequestId:" | wc -l)

echo "総呼び出し回数: $TOTAL_INVOCATIONS"
echo "コールドスタート回数: $COLD_STARTS"

if [ $TOTAL_INVOCATIONS -gt 0 ]; then
    PERCENTAGE=$(echo "scale=2; $COLD_STARTS * 100 / $TOTAL_INVOCATIONS" | bc)
    echo "コールドスタート率: ${PERCENTAGE}%"
fi

# Init期間を抽出
INIT_DURATIONS=$(echo "$LOGS" | grep "Init Duration:" | grep -o 'Init Duration: [0-9.]*' | awk '{print $3}')

if [ -n "$INIT_DURATIONS" ]; then
    AVG_INIT=$(echo "$INIT_DURATIONS" | awk '{sum+=$1} END {print sum/NR}')
    echo "平均Init期間: ${AVG_INIT}ms"
fi
```

---

## 実践的な例

### 例1: デイリーログレポート

```bash
#!/bin/bash
# daily-log-report.sh

LOG_GROUP="/aws/lambda/my-function"
REPORT_DATE=$(date -u -d 'yesterday' +%Y-%m-%d)
OUTPUT_FILE="log-report-${REPORT_DATE}.txt"

echo "=== Lambda ログレポート ===" > "$OUTPUT_FILE"
echo "関数名: my-function" >> "$OUTPUT_FILE"
echo "日付: $REPORT_DATE" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 時間範囲を設定
START_TIME=$(date -u -d "$REPORT_DATE 00:00:00" +%s)000
END_TIME=$(date -u -d "$REPORT_DATE 23:59:59" +%s)000

# 総呼び出し回数
TOTAL_INVOCATIONS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time "${REPORT_DATE}T00:00:00" \
    --end-time "${REPORT_DATE}T23:59:59" \
    --period 86400 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' \
    --output text)

echo "総呼び出し回数: ${TOTAL_INVOCATIONS:-0}" >> "$OUTPUT_FILE"

# エラー回数
ERROR_COUNT=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time "${REPORT_DATE}T00:00:00" \
    --end-time "${REPORT_DATE}T23:59:59" \
    --period 86400 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' \
    --output text)

echo "エラー回数: ${ERROR_COUNT:-0}" >> "$OUTPUT_FILE"

# 平均実行時間
AVG_DURATION=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time "${REPORT_DATE}T00:00:00" \
    --end-time "${REPORT_DATE}T23:59:59" \
    --period 86400 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

echo "平均実行時間: ${AVG_DURATION:-0}ms" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "=== エラーログ（最新10件）===" >> "$OUTPUT_FILE"

# エラーログを取得
aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "ERROR" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[:10].message' \
    --output text >> "$OUTPUT_FILE"

echo "レポート作成完了: $OUTPUT_FILE"
```

### 例2: リアルタイムアラート監視

```bash
#!/bin/bash
# realtime-alert-monitor.sh

LOG_GROUP="/aws/lambda/my-function"
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

echo "リアルタイムアラート監視を開始"
echo "Ctrl+Cで終了"

START_TIME=$(date -u +%s)000

while true; do
    END_TIME=$(date -u +%s)000
    
    # エラーログをチェック
    ERRORS=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "ERROR" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'events[*].message' \
        --output text)
    
    if [ -n "$ERRORS" ]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        ERROR_COUNT=$(echo "$ERRORS" | wc -l)
        
        echo "[$TIMESTAMP] エラー検出: $ERROR_COUNT 件"
        
        # Slackに通知（オプション）
        MESSAGE="Lambda関数でエラーが検出されました\n関数: my-function\n件数: $ERROR_COUNT\n時刻: $TIMESTAMP"
        
        curl -X POST "$WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$MESSAGE\"}" \
            2>/dev/null
    fi
    
    START_TIME=$END_TIME
    sleep 10
done
```

### 例3: ログベースのトラブルシューティング

```bash
#!/bin/bash
# troubleshoot-function.sh

FUNCTION_NAME="$1"

if [ -z "$FUNCTION_NAME" ]; then
    echo "使用方法: $0 <function-name>"
    exit 1
fi

LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

echo "==================================="
echo "Lambda トラブルシューティング"
echo "関数名: $FUNCTION_NAME"
echo "==================================="
echo ""

# 1. 最近のエラーをチェック
echo "1. 最近のエラー（過去1時間）"
echo "---"

ERROR_COUNT=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "ERROR" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'length(events)' \
    --output text)

echo "エラー件数: ${ERROR_COUNT:-0}"

if [ "$ERROR_COUNT" != "0" ] && [ -n "$ERROR_COUNT" ]; then
    echo "最新のエラー:"
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "ERROR" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'events[:3].message' \
        --output text
fi

echo ""

# 2. タイムアウトをチェック
echo "2. タイムアウトエラー"
echo "---"

TIMEOUT_COUNT=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "Task timed out" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'length(events)' \
    --output text)

echo "タイムアウト件数: ${TIMEOUT_COUNT:-0}"

echo ""

# 3. メモリエラーをチェック
echo "3. メモリ不足エラー"
echo "---"

MEMORY_ERROR_COUNT=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "?'out of memory' ?'OutOfMemory'" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'length(events)' \
    --output text)

echo "メモリエラー件数: ${MEMORY_ERROR_COUNT:-0}"

echo ""

# 4. コールドスタートを確認
echo "4. コールドスタート"
echo "---"

COLD_START_COUNT=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --filter-pattern "INIT_START" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'length(events)' \
    --output text)

echo "コールドスタート回数: ${COLD_START_COUNT:-0}"

echo ""

# 5. パフォーマンス統計
echo "5. パフォーマンス統計"
echo "---"

AVG_DURATION=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

echo "平均実行時間: ${AVG_DURATION:-N/A}ms"

# 6. スロットル状況
echo ""
echo "6. スロットル"
echo "---"

THROTTLE_COUNT=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Throttles \
    --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 3600 \
    --statistics Sum \
    --query 'Datapoints[0].Sum' \
    --output text)

echo "スロットル回数: ${THROTTLE_COUNT:-0}"

echo ""
echo "==================================="
echo "トラブルシューティング完了"
echo "==================================="
```

### 例4: ログの集計と統計

```bash
#!/bin/bash
# log-statistics.sh

LOG_GROUP="/aws/lambda/my-function"
HOURS="${1:-24}"  # デフォルトは24時間

START_TIME=$(date -u -d "$HOURS hours ago" +%s)000
END_TIME=$(date -u +%s)000

echo "=== ログ統計レポート ==="
echo "期間: 過去${HOURS}時間"
echo ""

# 総ログイベント数
TOTAL_EVENTS=$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'length(events)' \
    --output text)

echo "総ログイベント数: ${TOTAL_EVENTS:-0}"

# ログレベル別の集計
echo ""
echo "=== ログレベル別集計 ==="

for LEVEL in ERROR WARN INFO DEBUG; do
    COUNT=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "$LEVEL" \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --query 'length(events)' \
        --output text)
    
    echo "$LEVEL: ${COUNT:-0}"
done

# 時間帯別の集計
echo ""
echo "=== 時間帯別エラー集計 ==="

for i in $(seq 0 $((HOURS-1))); do
    HOUR_START=$(date -u -d "$((HOURS-i)) hours ago" +%s)000
    HOUR_END=$(date -u -d "$((HOURS-i-1)) hours ago" +%s)000
    HOUR_LABEL=$(date -u -d "$((HOURS-i)) hours ago" '+%Y-%m-%d %H:00')
    
    HOUR_ERRORS=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "ERROR" \
        --start-time $HOUR_START \
        --end-time $HOUR_END \
        --query 'length(events)' \
        --output text)
    
    echo "$HOUR_LABEL: ${HOUR_ERRORS:-0} エラー"
done
```

### 例5: ログアーカイブの自動化

```bash
#!/bin/bash
# archive-logs.sh

LOG_GROUP="/aws/lambda/my-function"
S3_BUCKET="my-log-archive"
ARCHIVE_DATE=$(date -u -d 'yesterday' +%Y-%m-%d)

echo "ログアーカイブを開始"
echo "日付: $ARCHIVE_DATE"

# ローカルにエクスポート
EXPORT_FILE="lambda-logs-${ARCHIVE_DATE}.log"

START_TIME=$(date -u -d "$ARCHIVE_DATE 00:00:00" +%s)000
END_TIME=$(date -u -d "$ARCHIVE_DATE 23:59:59" +%s)000

aws logs filter-log-events \
    --log-group-name "$LOG_GROUP" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'events[*].[timestamp,logStreamName,message]' \
    --output text > "$EXPORT_FILE"

# 圧縮
gzip "$EXPORT_FILE"
COMPRESSED_FILE="${EXPORT_FILE}.gz"

echo "ログを圧縮: $COMPRESSED_FILE"

# S3にアップロード
S3_KEY="lambda-logs/my-function/${ARCHIVE_DATE}/${COMPRESSED_FILE}"

aws s3 cp "$COMPRESSED_FILE" "s3://${S3_BUCKET}/${S3_KEY}"

if [ $? -eq 0 ]; then
    echo "S3にアップロード完了: s3://${S3_BUCKET}/${S3_KEY}"
    
    # ローカルファイルを削除
    rm "$COMPRESSED_FILE"
    echo "ローカルファイルを削除"
else
    echo "エラー: S3へのアップロードに失敗しました"
    exit 1
fi

# 古いログストリームを削除（オプション）
# 注意: 本番環境では慎重に実行してください
# DELETE_BEFORE=$(date -u -d '30 days ago' +%s)000
# aws logs describe-log-streams \
#     --log-group-name "$LOG_GROUP" \
#     --order-by LastEventTime \
#     --ascending \
#     --query "logStreams[?lastEventTime<$DELETE_BEFORE].logStreamName" \
#     --output text | while read STREAM; do
#         aws logs delete-log-stream \
#             --log-group-name "$LOG_GROUP" \
#             --log-stream-name "$STREAM"
#         echo "削除: $STREAM"
#     done

echo "アーカイブ完了"
```

### 例6: マルチリージョンログ監視

```bash
#!/bin/bash
# multi-region-log-monitor.sh

FUNCTION_NAME="my-function"
REGIONS=("us-east-1" "eu-west-1" "ap-northeast-1")
FILTER_PATTERN="ERROR"

echo "=== マルチリージョンログ監視 ==="
echo "関数名: $FUNCTION_NAME"
echo "リージョン: ${REGIONS[*]}"
echo ""

START_TIME=$(date -u -d '1 hour ago' +%s)000
END_TIME=$(date -u +%s)000

for REGION in "${REGIONS[@]}"; do
    echo "--- $REGION ---"
    
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    
    # ロググループの存在確認
    if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" \
        --query 'logGroups[0]' \
        --output text &>/dev/null; then
        
        ERROR_COUNT=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --filter-pattern "$FILTER_PATTERN" \
            --start-time $START_TIME \
            --end-time $END_TIME \
            --region "$REGION" \
            --query 'length(events)' \
            --output text)
        
        echo "エラー件数: ${ERROR_COUNT:-0}"
        
        if [ "$ERROR_COUNT" != "0" ] && [ -n "$ERROR_COUNT" ]; then
            echo "最新のエラー:"
            aws logs filter-log-events \
                --log-group-name "$LOG_GROUP" \
                --filter-pattern "$FILTER_PATTERN" \
                --start-time $START_TIME \
                --end-time $END_TIME \
                --region "$REGION" \
                --query 'events[0].message' \
                --output text
        fi
    else
        echo "ロググループが見つかりません"
    fi
    
    echo ""
done
```

---

## ベストプラクティス

### 1. ログ保存期間の設定

```bash
# コスト最適化のため、適切な保存期間を設定
# 開発環境: 7日
aws logs put-retention-policy \
    --log-group-name /aws/lambda/dev-function \
    --retention-in-days 7

# ステージング環境: 30日
aws logs put-retention-policy \
    --log-group-name /aws/lambda/staging-function \
    --retention-in-days 30

# 本番環境: 90日
aws logs put-retention-policy \
    --log-group-name /aws/lambda/prod-function \
    --retention-in-days 90
```

### 2. 構造化ログの活用

```python
# Lambda関数内で構造化ログを出力
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # 構造化ログ
    log_data = {
        "level": "INFO",
        "message": "Processing request",
        "userId": event.get("userId"),
        "requestId": context.request_id,
        "timestamp": context.get_remaining_time_in_millis()
    }
    logger.info(json.dumps(log_data))
```

```bash
# 構造化ログのフィルタリング
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern '{ $.level = "ERROR" && $.userId = "user-123" }'
```

### 3. ログ分析の自動化

```bash
#!/bin/bash
# daily-log-analysis.sh
# Cronで毎日実行: 0 1 * * * /path/to/daily-log-analysis.sh

FUNCTIONS=("api-handler" "data-processor" "notification-service")

for FUNCTION in "${FUNCTIONS[@]}"; do
    ./analyze-errors.sh "$FUNCTION" >> "logs/analysis-$(date +%Y%m%d).log"
done

# 異常を検出した場合は通知
ERROR_THRESHOLD=100
for FUNCTION in "${FUNCTIONS[@]}"; do
    ERROR_COUNT=$(grep "総エラー数" "logs/analysis-$(date +%Y%m%d).log" | tail -1 | awk '{print $2}')
    
    if [ "$ERROR_COUNT" -gt "$ERROR_THRESHOLD" ]; then
        # アラート送信
        echo "高エラー率を検出: $FUNCTION"
    fi
done
```

### 4. コスト最適化

```bash
# ログのサイズを確認
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/ \
    --query 'logGroups[*].[logGroupName,storedBytes]' \
    --output table

# 大きなロググループを特定
aws logs describe-log-groups \
    --log-group-name-prefix /aws/lambda/ \
    --query 'logGroups[?storedBytes>`10737418240`].[logGroupName,storedBytes]' \
    --output table

# 古いログストリームを削除してコスト削減
# （保存期間設定の方が推奨）
```

---

## トラブルシューティング

### よくある問題と解決策

**1. ロググループが見つからない**
```bash
# 原因: 関数が一度も実行されていない
# 解決: 関数を一度実行してロググループを作成
aws lambda invoke \
    --function-name my-function \
    --payload '{}' \
    response.json
```

**2. ログが表示されない**
```bash
# 原因: IAM実行ロールにCloudWatch Logsへの書き込み権限がない
# 解決: 必要なポリシーを追加

# 必要な権限:
# - logs:CreateLogGroup
# - logs:CreateLogStream
# - logs:PutLogEvents
```

**3. フィルタパターンが機能しない**
```bash
# 原因: パターンの構文が不正
# 解決: シンプルなパターンから開始

# 単純なテキスト検索
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR"

# 複雑なパターンはドキュメントを参照
```

**4. ログの取得が遅い**
```bash
# 原因: 時間範囲が広すぎる
# 解決: 時間範囲を狭める、ページネーションを使用

# 最大1時間に制限
START_TIME=$(date -u -d '1 hour ago' +%s)000
```

---

## 関連リソース

- [Lambda関数管理](./function_management.md)
- [Lambda関数の呼び出し](./invocation.md)
- [出力フォーマットとフィルタリング](../06_output_formatting/filtering.md)
- [AWS CloudWatch Logs公式ドキュメント](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [Lambda モニタリングのベストプラクティス](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html)

---

## まとめ

Lambda関数のログ管理における重要なポイント:

1. **ロググループの管理**: 適切な保存期間の設定でコスト最適化
2. **効果的なフィルタリング**: パターンマッチングで必要な情報を素早く取得
3. **リアルタイム監視**: 継続的な監視とアラートでトラブルを早期発見
4. **メトリクス分析**: CloudWatch Metricsと組み合わせた包括的な監視
5. **自動化**: スクリプトによる定期的なログ分析とアーカイブ

これらのテクニックを活用することで、Lambda関数の運用を効率化し、問題の迅速な検出と解決が可能になります。
