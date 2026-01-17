# Lambda関数の呼び出し (Invocation)

## 目次
- [基本的な呼び出し](#基本的な呼び出し)
- [同期 vs 非同期呼び出し](#同期-vs-非同期呼び出し)
- [ペイロードの渡し方](#ペイロードの渡し方)
- [レスポンスの処理](#レスポンスの処理)
- [呼び出しタイプ](#呼び出しタイプ)
- [様々なペイロードでのテスト](#様々なペイロードでのテスト)
- [エラーハンドリング](#エラーハンドリング)
- [実践的な例](#実践的な例)

## 基本的な呼び出し

### シンプルな関数呼び出し
```bash
# 基本的な呼び出し
aws lambda invoke \
  --function-name my-function \
  response.json

# 出力結果を確認
cat response.json
```

### 関数のバージョンやエイリアスを指定
```bash
# 特定のバージョンを呼び出し
aws lambda invoke \
  --function-name my-function:5 \
  response.json

# エイリアスを指定して呼び出し
aws lambda invoke \
  --function-name my-function:prod \
  response.json
```

## 同期 vs 非同期呼び出し

### 同期呼び出し (RequestResponse)
関数の実行が完了するまで待機し、結果を返します。

```bash
# 同期呼び出し(デフォルト)
aws lambda invoke \
  --function-name my-function \
  --invocation-type RequestResponse \
  response.json

# ステータスコードを確認
echo $?
```

### 非同期呼び出し (Event)
関数をトリガーして即座に戻ります。実行結果は待ちません。

```bash
# 非同期呼び出し
aws lambda invoke \
  --function-name my-function \
  --invocation-type Event \
  response.json

# レスポンスには実行結果は含まれず、ステータスコード202が返る
cat response.json
```

### DryRun(ドライラン)
実際に関数を実行せず、呼び出し権限を検証します。

```bash
# ドライラン - 権限チェックのみ
aws lambda invoke \
  --function-name my-function \
  --invocation-type DryRun \
  response.json
```

## ペイロードの渡し方

### インラインJSONペイロード
```bash
# シンプルなJSONペイロード
aws lambda invoke \
  --function-name my-function \
  --payload '{"key1":"value1","key2":"value2"}' \
  response.json

# 数値や配列を含むペイロード
aws lambda invoke \
  --function-name my-function \
  --payload '{"userId":123,"items":["item1","item2","item3"]}' \
  response.json
```

### ファイルからペイロードを読み込む
```bash
# JSONファイルからペイロードを読み込む
aws lambda invoke \
  --function-name my-function \
  --payload file://input.json \
  response.json

# Base64エンコードされたペイロード
aws lambda invoke \
  --function-name my-function \
  --payload fileb://binary-data.bin \
  response.json
```

### 複雑なペイロードの例
```bash
# input.json の内容例
cat > input.json << 'EOF'
{
  "operation": "process",
  "data": {
    "userId": "user-123",
    "timestamp": "2025-11-15T10:00:00Z",
    "items": [
      {"id": 1, "name": "item1", "quantity": 5},
      {"id": 2, "name": "item2", "quantity": 3}
    ],
    "metadata": {
      "source": "api",
      "priority": "high"
    }
  }
}
EOF

# ファイルを使用して呼び出し
aws lambda invoke \
  --function-name data-processor \
  --payload file://input.json \
  output.json
```

## レスポンスの処理

### 基本的なレスポンス確認
```bash
# 関数を呼び出してレスポンスを確認
aws lambda invoke \
  --function-name my-function \
  --payload '{"name":"Taro"}' \
  response.json

# レスポンスの内容を表示
cat response.json

# jqを使って整形して表示
cat response.json | jq '.'
```

### ログテールの表示
```bash
# 実行ログの最後の4KBを取得
aws lambda invoke \
  --function-name my-function \
  --log-type Tail \
  --payload '{"test":"data"}' \
  response.json

# ログをBase64デコードして表示
aws lambda invoke \
  --function-name my-function \
  --log-type Tail \
  --payload '{"test":"data"}' \
  response.json \
  --query 'LogResult' \
  --output text | base64 --decode
```

### レスポンスメタデータの取得
```bash
# すべてのメタデータを含めて表示
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json \
  --cli-binary-format raw-in-base64-out

# ステータスコードを確認
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json \
  --query 'StatusCode' \
  --output text

# 実行されたバージョンを確認
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json \
  --query 'ExecutedVersion' \
  --output text
```

## 呼び出しタイプ

### RequestResponse (同期)
```bash
# デフォルトの同期呼び出し
aws lambda invoke \
  --function-name calculate-sum \
  --invocation-type RequestResponse \
  --payload '{"numbers":[1,2,3,4,5]}' \
  result.json

# 結果を即座に取得できる
cat result.json
# 出力例: {"sum":15,"count":5}
```

### Event (非同期)
```bash
# イベントとして非同期で実行
aws lambda invoke \
  --function-name send-notification \
  --invocation-type Event \
  --payload '{"email":"user@example.com","message":"Hello"}' \
  response.json

# すぐに制御が戻る(StatusCode: 202)
# 実際の実行結果はCloudWatch Logsで確認
```

### DryRun (検証のみ)
```bash
# 実行権限の検証のみ
aws lambda invoke \
  --function-name my-function \
  --invocation-type DryRun \
  --payload '{"test":"data"}' \
  response.json

# 成功: StatusCode 204
# 失敗: エラーメッセージが返る
```

## 様々なペイロードでのテスト

### API Gatewayイベントのシミュレーション
```bash
cat > api-gateway-event.json << 'EOF'
{
  "httpMethod": "POST",
  "path": "/users",
  "headers": {
    "Content-Type": "application/json",
    "Authorization": "Bearer token123"
  },
  "queryStringParameters": {
    "page": "1",
    "limit": "10"
  },
  "body": "{\"name\":\"John Doe\",\"email\":\"john@example.com\"}",
  "isBase64Encoded": false
}
EOF

aws lambda invoke \
  --function-name api-handler \
  --payload file://api-gateway-event.json \
  api-response.json
```

### S3イベントのシミュレーション
```bash
cat > s3-event.json << 'EOF'
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "my-bucket",
          "arn": "arn:aws:s3:::my-bucket"
        },
        "object": {
          "key": "uploads/image.jpg",
          "size": 1024000
        }
      }
    }
  ]
}
EOF

aws lambda invoke \
  --function-name s3-processor \
  --payload file://s3-event.json \
  s3-response.json
```

### DynamoDB Streamイベントのシミュレーション
```bash
cat > dynamodb-event.json << 'EOF'
{
  "Records": [
    {
      "eventID": "1",
      "eventName": "INSERT",
      "eventVersion": "1.0",
      "eventSource": "aws:dynamodb",
      "dynamodb": {
        "Keys": {
          "Id": {"N": "101"}
        },
        "NewImage": {
          "Id": {"N": "101"},
          "Name": {"S": "Product A"},
          "Price": {"N": "29.99"}
        },
        "SequenceNumber": "111",
        "SizeBytes": 26,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      }
    }
  ]
}
EOF

aws lambda invoke \
  --function-name dynamodb-trigger \
  --payload file://dynamodb-event.json \
  dynamodb-response.json
```

### CloudWatch Scheduled Eventのシミュレーション
```bash
cat > scheduled-event.json << 'EOF'
{
  "version": "0",
  "id": "scheduled-event-id",
  "detail-type": "Scheduled Event",
  "source": "aws.events",
  "time": "2025-11-15T10:00:00Z",
  "region": "ap-northeast-1",
  "resources": [
    "arn:aws:events:ap-northeast-1:123456789012:rule/my-scheduled-rule"
  ],
  "detail": {}
}
EOF

aws lambda invoke \
  --function-name scheduled-task \
  --payload file://scheduled-event.json \
  scheduled-response.json
```

## エラーハンドリング

### 関数エラーの検出
```bash
# 関数内でエラーが発生した場合
aws lambda invoke \
  --function-name my-function \
  --payload '{"invalidData":true}' \
  error-response.json

# FunctionErrorフィールドでエラータイプを確認
aws lambda invoke \
  --function-name my-function \
  --payload '{"causeError":true}' \
  error-response.json \
  --query 'FunctionError' \
  --output text

# エラー詳細はレスポンスファイルに含まれる
cat error-response.json
```

### タイムアウトの処理
```bash
# タイムアウト設定の確認
aws lambda get-function-configuration \
  --function-name my-function \
  --query 'Timeout' \
  --output text

# 長時間実行される可能性がある処理
aws lambda invoke \
  --function-name long-running-task \
  --payload '{"processLargeFile":true}' \
  timeout-response.json

# タイムアウトエラーの場合、FunctionErrorに"Unhandled"が設定される
```

### スロットリングエラーの処理
```bash
# 同時実行数制限に達した場合
aws lambda invoke \
  --function-name my-function \
  --payload '{"data":"test"}' \
  response.json 2>&1 | tee invoke-error.log

# エラーメッセージ例:
# TooManyRequestsException: Rate exceeded
```

### リトライロジックの実装
```bash
#!/bin/bash
# invoke-with-retry.sh

FUNCTION_NAME=$1
PAYLOAD=$2
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "呼び出し試行: $((RETRY_COUNT + 1))/$MAX_RETRIES"
  
  if aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "$PAYLOAD" \
    response.json 2>error.log; then
    
    # FunctionErrorをチェック
    FUNCTION_ERROR=$(jq -r '.FunctionError // "none"' <<< \
      $(aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload "$PAYLOAD" \
        response.json \
        --query 'FunctionError' \
        --output text))
    
    if [ "$FUNCTION_ERROR" == "none" ] || [ "$FUNCTION_ERROR" == "None" ]; then
      echo "呼び出し成功"
      cat response.json
      exit 0
    else
      echo "関数エラー: $FUNCTION_ERROR"
    fi
  else
    echo "AWS CLIエラー:"
    cat error.log
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
    WAIT_TIME=$((2 ** RETRY_COUNT))
    echo "待機: ${WAIT_TIME}秒"
    sleep $WAIT_TIME
  fi
done

echo "最大リトライ回数に達しました"
exit 1
```

## 実践的な例

### 例1: バッチ処理のテスト
```bash
#!/bin/bash
# batch-invoke-test.sh

FUNCTION_NAME="data-processor"

# テストケースの配列
declare -a TEST_CASES=(
  '{"userId":"user-001","action":"create"}'
  '{"userId":"user-002","action":"update"}'
  '{"userId":"user-003","action":"delete"}'
)

# 各テストケースを実行
for i in "${!TEST_CASES[@]}"; do
  echo "テストケース $((i+1)): ${TEST_CASES[$i]}"
  
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "${TEST_CASES[$i]}" \
    "response-${i}.json" \
    --log-type Tail \
    --query 'LogResult' \
    --output text | base64 --decode
  
  echo "レスポンス:"
  cat "response-${i}.json" | jq '.'
  echo "---"
done
```

### 例2: パフォーマンステスト
```bash
#!/bin/bash
# performance-test.sh

FUNCTION_NAME="my-function"
ITERATIONS=10
PAYLOAD='{"test":"data"}'

echo "パフォーマンステスト開始: $ITERATIONS 回の呼び出し"
echo "関数名: $FUNCTION_NAME"
echo ""

TOTAL_DURATION=0

for i in $(seq 1 $ITERATIONS); do
  START_TIME=$(date +%s%3N)
  
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "$PAYLOAD" \
    "perf-response-${i}.json" \
    > /dev/null 2>&1
  
  END_TIME=$(date +%s%3N)
  DURATION=$((END_TIME - START_TIME))
  TOTAL_DURATION=$((TOTAL_DURATION + DURATION))
  
  echo "呼び出し #${i}: ${DURATION}ms"
done

AVERAGE=$((TOTAL_DURATION / ITERATIONS))
echo ""
echo "合計時間: ${TOTAL_DURATION}ms"
echo "平均時間: ${AVERAGE}ms"

# クリーンアップ
rm -f perf-response-*.json
```

### 例3: 環境別テスト
```bash
#!/bin/bash
# multi-environment-test.sh

FUNCTION_BASE_NAME="my-function"
PAYLOAD='{"environment":"test"}'

# 環境のリスト
ENVIRONMENTS=("dev" "staging" "prod")

for ENV in "${ENVIRONMENTS[@]}"; do
  FUNCTION_NAME="${FUNCTION_BASE_NAME}-${ENV}"
  
  echo "テスト環境: $ENV"
  echo "関数名: $FUNCTION_NAME"
  
  # 関数の存在確認
  if aws lambda get-function --function-name "$FUNCTION_NAME" > /dev/null 2>&1; then
    # 関数を呼び出し
    aws lambda invoke \
      --function-name "$FUNCTION_NAME" \
      --payload "$PAYLOAD" \
      "response-${ENV}.json"
    
    # 結果を表示
    echo "レスポンス:"
    cat "response-${ENV}.json" | jq '.'
  else
    echo "警告: 関数 $FUNCTION_NAME が見つかりません"
  fi
  
  echo "---"
done
```

### 例4: エラーケーステスト
```bash
#!/bin/bash
# error-case-test.sh

FUNCTION_NAME="error-handler-function"

# エラーケースの定義
declare -A ERROR_CASES=(
  ["空のペイロード"]='{}'
  ["不正な形式"]='{invalid}'
  ["必須フィールド欠落"]='{}'
  ["型不一致"]='{\"count\":\"not-a-number\"}'
  ["範囲外の値"]='{\"value\":-999}'
)

echo "エラーケーステスト開始"
echo "関数名: $FUNCTION_NAME"
echo ""

PASSED=0
FAILED=0

for TEST_NAME in "${!ERROR_CASES[@]}"; do
  PAYLOAD="${ERROR_CASES[$TEST_NAME]}"
  
  echo "テスト: $TEST_NAME"
  echo "ペイロード: $PAYLOAD"
  
  # 関数を呼び出し
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "$PAYLOAD" \
    error-response.json 2>error.log
  
  # エラーの有無を確認
  if grep -q "error" error-response.json; then
    echo "結果: ✓ エラーが正しく処理されました"
    PASSED=$((PASSED + 1))
  else
    echo "結果: ✗ エラー処理が期待と異なります"
    FAILED=$((FAILED + 1))
  fi
  
  cat error-response.json | jq '.'
  echo "---"
done

echo ""
echo "テスト結果: 成功 $PASSED / 失敗 $FAILED"

# クリーンアップ
rm -f error-response.json error.log
```

### 例5: 並列呼び出しテスト
```bash
#!/bin/bash
# concurrent-invoke-test.sh

FUNCTION_NAME="concurrent-test-function"
CONCURRENT_CALLS=5

echo "並列呼び出しテスト: $CONCURRENT_CALLS 並列実行"
echo "関数名: $FUNCTION_NAME"
echo ""

# バックグラウンドで並列実行
for i in $(seq 1 $CONCURRENT_CALLS); do
  (
    PAYLOAD="{\"requestId\":\"req-${i}\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    
    START=$(date +%s%3N)
    aws lambda invoke \
      --function-name "$FUNCTION_NAME" \
      --payload "$PAYLOAD" \
      "concurrent-response-${i}.json" \
      > /dev/null 2>&1
    END=$(date +%s%3N)
    
    DURATION=$((END - START))
    echo "リクエスト #${i}: ${DURATION}ms"
  ) &
done

# すべてのバックグラウンドジョブの完了を待つ
wait

echo ""
echo "すべての並列呼び出しが完了しました"
echo "レスポンスファイル:"
ls -lh concurrent-response-*.json

# クリーンアップするか確認
read -p "レスポンスファイルを削除しますか? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f concurrent-response-*.json
  echo "クリーンアップ完了"
fi
```

### 例6: 実践的なデータ処理パイプライン
```bash
#!/bin/bash
# data-pipeline-test.sh

# ステップ1: データ抽出
echo "ステップ1: データ抽出"
aws lambda invoke \
  --function-name data-extractor \
  --payload '{"source":"database","table":"users"}' \
  extract-output.json

EXTRACTED_DATA=$(cat extract-output.json | jq -r '.data')
echo "抽出されたデータ: $EXTRACTED_DATA"

# ステップ2: データ変換
echo ""
echo "ステップ2: データ変換"
aws lambda invoke \
  --function-name data-transformer \
  --payload "{\"data\":$EXTRACTED_DATA,\"transformation\":\"normalize\"}" \
  transform-output.json

TRANSFORMED_DATA=$(cat transform-output.json | jq -r '.data')
echo "変換されたデータ: $TRANSFORMED_DATA"

# ステップ3: データロード
echo ""
echo "ステップ3: データロード"
aws lambda invoke \
  --function-name data-loader \
  --payload "{\"data\":$TRANSFORMED_DATA,\"destination\":\"s3\"}" \
  load-output.json

echo "ロード結果:"
cat load-output.json | jq '.'

# クリーンアップ
rm -f extract-output.json transform-output.json load-output.json
```

## ベストプラクティス

### 1. ペイロードサイズの確認
```bash
# ペイロードのサイズを確認(同期: 6MB、非同期: 256KB制限)
PAYLOAD_FILE="large-payload.json"
SIZE=$(wc -c < "$PAYLOAD_FILE")
SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)

echo "ペイロードサイズ: ${SIZE_MB}MB"

if (( $(echo "$SIZE_MB > 6" | bc -l) )); then
  echo "エラー: ペイロードが6MBを超えています"
  exit 1
fi

aws lambda invoke \
  --function-name my-function \
  --payload "file://$PAYLOAD_FILE" \
  response.json
```

### 2. ログの効果的な活用
```bash
# ログを取得して分析
aws lambda invoke \
  --function-name my-function \
  --log-type Tail \
  --payload '{"debug":true}' \
  response.json \
  --query 'LogResult' \
  --output text | base64 --decode | tee execution.log

# ログからエラーを抽出
grep -i "error\|exception\|fail" execution.log
```

### 3. コスト最適化
```bash
# 非同期呼び出しを使用してコストを削減
# (レスポンスを待つ必要がない場合)
aws lambda invoke \
  --function-name background-task \
  --invocation-type Event \
  --payload '{"task":"cleanup"}' \
  response.json

# DryRunで事前検証(実行コストなし)
aws lambda invoke \
  --function-name expensive-function \
  --invocation-type DryRun \
  --payload '{"testMode":true}' \
  response.json
```

## トラブルシューティング

### よくあるエラーと解決方法

```bash
# 1. InvalidRequestContentException
# 原因: ペイロードの形式が不正
# 解決: JSONの構文を確認
echo '{"key":"value"}' | jq '.'  # JSON検証

# 2. ResourceNotFoundException
# 原因: 関数が存在しない
# 解決: 関数名を確認
aws lambda list-functions --query 'Functions[].FunctionName'

# 3. TooManyRequestsException
# 原因: 同時実行数制限
# 解決: リトライロジックの実装、予約済み同時実行数の設定
aws lambda put-function-concurrency \
  --function-name my-function \
  --reserved-concurrent-executions 10

# 4. AccessDeniedException
# 原因: 実行権限がない
# 解決: IAMポリシーを確認
aws lambda get-policy --function-name my-function
```

## まとめ

Lambda関数の呼び出しは、AWS CLIを使用することで柔軟にテストと自動化が可能です:

- **同期呼び出し**: 即座に結果が必要な場合
- **非同期呼び出し**: バックグラウンド処理に適している
- **DryRun**: 権限検証やコスト削減
- **ペイロード**: JSON形式またはファイルから読み込み
- **エラーハンドリング**: リトライロジックとログ分析
- **テスト戦略**: 様々なイベントタイプのシミュレーション

これらのテクニックを組み合わせて、本番環境で堅牢なLambda関数を構築できます。
