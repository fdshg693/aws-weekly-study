# Lambda 関数管理

AWS Lambda関数の作成、更新、削除、バージョン管理などの管理操作に関するAWS CLIコマンドガイド。

## 目次
- [関数の作成](#関数の作成)
- [関数コードの更新](#関数コードの更新)
- [関数設定の更新](#関数設定の更新)
- [関数の一覧表示](#関数の一覧表示)
- [関数情報の取得](#関数情報の取得)
- [関数の削除](#関数の削除)
- [バージョン管理](#バージョン管理)
- [エイリアス管理](#エイリアス管理)
- [実践的な例](#実践的な例)

---

## 関数の作成

### 基本的な関数作成

```bash
# ZIPファイルから関数を作成
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip
```

**パラメータ説明:**
- `--function-name`: 関数名（必須）
- `--runtime`: ランタイム環境（必須）
- `--role`: 実行ロールのARN（必須）
- `--handler`: ハンドラー関数（必須）
- `--zip-file`: コードのZIPファイル

### サポートされているランタイム

```bash
# 利用可能なランタイム一覧
# Python: python3.11, python3.10, python3.9, python3.8
# Node.js: nodejs20.x, nodejs18.x, nodejs16.x
# Java: java17, java11, java8.al2
# .NET: dotnet8, dotnet6
# Go: provided.al2023, provided.al2
# Ruby: ruby3.2
```

### 環境変数を含む関数作成

```bash
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables={DB_HOST=mydb.example.com,DB_PORT=5432,ENV=production}
```

### メモリとタイムアウトの設定

```bash
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --memory-size 512 \
    --timeout 30 \
    --description "データ処理用Lambda関数"
```

**リソース制限:**
- `--memory-size`: 128MB〜10,240MB（64MBずつ増加）
- `--timeout`: 1秒〜900秒（15分）

### レイヤーを使用した関数作成

```bash
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --layers arn:aws:lambda:ap-northeast-1:123456789012:layer:my-layer:1 \
           arn:aws:lambda:ap-northeast-1:123456789012:layer:numpy-layer:3
```

### VPC設定を含む関数作成

```bash
aws lambda create-function \
    --function-name my-vpc-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-vpc-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --vpc-config SubnetIds=subnet-12345678,subnet-87654321,SecurityGroupIds=sg-12345678
```

### デッドレターキュー（DLQ）の設定

```bash
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --dead-letter-config TargetArn=arn:aws:sqs:ap-northeast-1:123456789012:lambda-dlq
```

### タグ付きで関数作成

```bash
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --tags Environment=production,Team=backend,Project=data-pipeline
```

---

## 関数コードの更新

### ZIPファイルからコード更新

```bash
aws lambda update-function-code \
    --function-name my-function \
    --zip-file fileb://function-v2.zip
```

### S3バケットからコード更新

```bash
# S3にコードをアップロード
aws s3 cp function.zip s3://my-lambda-bucket/functions/

# S3からコードを更新
aws lambda update-function-code \
    --function-name my-function \
    --s3-bucket my-lambda-bucket \
    --s3-key functions/function.zip
```

### S3のバージョン指定でコード更新

```bash
aws lambda update-function-code \
    --function-name my-function \
    --s3-bucket my-lambda-bucket \
    --s3-key functions/function.zip \
    --s3-object-version abc123xyz456
```

### コンテナイメージでコード更新

```bash
aws lambda update-function-code \
    --function-name my-container-function \
    --image-uri 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-lambda:latest
```

### 更新を公開（バージョン作成）

```bash
aws lambda update-function-code \
    --function-name my-function \
    --zip-file fileb://function.zip \
    --publish
```

---

## 関数設定の更新

### ハンドラーとランタイムの更新

```bash
aws lambda update-function-configuration \
    --function-name my-function \
    --runtime python3.11 \
    --handler new_handler.main
```

### 環境変数の更新

```bash
# 環境変数を上書き
aws lambda update-function-configuration \
    --function-name my-function \
    --environment Variables={DB_HOST=newdb.example.com,DB_PORT=5432,API_KEY=secret123}
```

```bash
# 既存の環境変数を取得して一部を変更（シェルスクリプト例）
CURRENT_ENV=$(aws lambda get-function-configuration \
    --function-name my-function \
    --query 'Environment.Variables' \
    --output json)

# 新しい環境変数をマージして更新
aws lambda update-function-configuration \
    --function-name my-function \
    --environment Variables={DB_HOST=newdb.example.com,DB_PORT=5432,ENV=staging}
```

### メモリとタイムアウトの変更

```bash
aws lambda update-function-configuration \
    --function-name my-function \
    --memory-size 1024 \
    --timeout 60
```

### レイヤーの更新

```bash
# レイヤーを追加または変更
aws lambda update-function-configuration \
    --function-name my-function \
    --layers arn:aws:lambda:ap-northeast-1:123456789012:layer:my-layer:2 \
           arn:aws:lambda:ap-northeast-1:123456789012:layer:requests-layer:1
```

```bash
# すべてのレイヤーを削除
aws lambda update-function-configuration \
    --function-name my-function \
    --layers []
```

### VPC設定の更新

```bash
# VPC設定を変更
aws lambda update-function-configuration \
    --function-name my-function \
    --vpc-config SubnetIds=subnet-new123,subnet-new456,SecurityGroupIds=sg-new123
```

```bash
# VPC設定を削除
aws lambda update-function-configuration \
    --function-name my-function \
    --vpc-config SubnetIds=[],SecurityGroupIds=[]
```

### デッドレターキューの更新

```bash
aws lambda update-function-configuration \
    --function-name my-function \
    --dead-letter-config TargetArn=arn:aws:sqs:ap-northeast-1:123456789012:new-dlq
```

### IAM実行ロールの変更

```bash
aws lambda update-function-configuration \
    --function-name my-function \
    --role arn:aws:iam::123456789012:role/new-lambda-execution-role
```

### 説明の更新

```bash
aws lambda update-function-configuration \
    --function-name my-function \
    --description "更新されたデータ処理関数 - v2.0"
```

---

## 関数の一覧表示

### すべての関数を一覧表示

```bash
aws lambda list-functions
```

### 関数名のみを表示

```bash
aws lambda list-functions \
    --query 'Functions[*].FunctionName' \
    --output text
```

### 特定のランタイムの関数を表示

```bash
aws lambda list-functions \
    --query 'Functions[?Runtime==`python3.11`].[FunctionName,Runtime,LastModified]' \
    --output table
```

### 関数名、ランタイム、メモリを表形式で表示

```bash
aws lambda list-functions \
    --query 'Functions[*].[FunctionName,Runtime,MemorySize,Timeout]' \
    --output table
```

### ページネーション

```bash
# 最初の10件を取得
aws lambda list-functions \
    --max-items 10

# 次のページを取得（NextTokenを使用）
aws lambda list-functions \
    --max-items 10 \
    --starting-token <previous-next-token>
```

### 特定の関数名パターンで絞り込み

```bash
# "prod-"で始まる関数
aws lambda list-functions \
    --query 'Functions[?starts_with(FunctionName, `prod-`)].[FunctionName,Runtime]' \
    --output table
```

---

## 関数情報の取得

### 関数の設定情報を取得

```bash
aws lambda get-function-configuration \
    --function-name my-function
```

### 関数の完全な情報を取得

```bash
aws lambda get-function \
    --function-name my-function
```

### 特定のバージョンの情報を取得

```bash
aws lambda get-function \
    --function-name my-function \
    --qualifier 5
```

### 関数のARNのみを取得

```bash
aws lambda get-function-configuration \
    --function-name my-function \
    --query 'FunctionArn' \
    --output text
```

### 環境変数のみを取得

```bash
aws lambda get-function-configuration \
    --function-name my-function \
    --query 'Environment.Variables'
```

### 関数のコードダウンロードURL取得

```bash
aws lambda get-function \
    --function-name my-function \
    --query 'Code.Location' \
    --output text
```

---

## 関数の削除

### 関数を削除

```bash
aws lambda delete-function \
    --function-name my-function
```

### 特定のバージョンを削除

```bash
# 注意: $LATESTや番号付きバージョンは削除できません
# エイリアスを使用している場合は、エイリアスを先に削除する必要があります
```

### 削除確認付きスクリプト例

```bash
#!/bin/bash
FUNCTION_NAME="my-function"

echo "関数 $FUNCTION_NAME を削除しようとしています"
read -p "本当に削除しますか？ (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    aws lambda delete-function --function-name $FUNCTION_NAME
    echo "関数が削除されました"
else
    echo "削除がキャンセルされました"
fi
```

---

## バージョン管理

### 新しいバージョンを公開

```bash
aws lambda publish-version \
    --function-name my-function \
    --description "初回リリース v1.0"
```

### コード更新と同時にバージョン公開

```bash
aws lambda update-function-code \
    --function-name my-function \
    --zip-file fileb://function.zip \
    --publish
```

### すべてのバージョンを一覧表示

```bash
aws lambda list-versions-by-function \
    --function-name my-function
```

### バージョン番号と説明を表示

```bash
aws lambda list-versions-by-function \
    --function-name my-function \
    --query 'Versions[*].[Version,Description,LastModified]' \
    --output table
```

### 特定のバージョン情報を取得

```bash
aws lambda get-function \
    --function-name my-function \
    --qualifier 3
```

### バージョンを呼び出し

```bash
aws lambda invoke \
    --function-name my-function \
    --qualifier 5 \
    --payload '{"key": "value"}' \
    response.json
```

---

## エイリアス管理

### エイリアスの作成

```bash
aws lambda create-alias \
    --function-name my-function \
    --name production \
    --function-version 5 \
    --description "本番環境用エイリアス"
```

### 重み付きエイリアス（トラフィック分割）

```bash
# バージョン5に90%、バージョン6に10%のトラフィックを振り分け
aws lambda create-alias \
    --function-name my-function \
    --name canary \
    --function-version 5 \
    --routing-config AdditionalVersionWeights={"6"=0.1}
```

### エイリアスの更新

```bash
aws lambda update-alias \
    --function-name my-function \
    --name production \
    --function-version 6
```

### エイリアスのトラフィック分割を変更

```bash
# バージョン6に70%、バージョン7に30%
aws lambda update-alias \
    --function-name my-function \
    --name canary \
    --function-version 6 \
    --routing-config AdditionalVersionWeights={"7"=0.3}
```

### エイリアス一覧を表示

```bash
aws lambda list-aliases \
    --function-name my-function
```

### エイリアス情報を取得

```bash
aws lambda get-alias \
    --function-name my-function \
    --name production
```

### エイリアスを削除

```bash
aws lambda delete-alias \
    --function-name my-function \
    --name staging
```

### エイリアス経由で関数を呼び出し

```bash
aws lambda invoke \
    --function-name my-function \
    --qualifier production \
    --payload '{"key": "value"}' \
    response.json
```

---

## 実践的な例

### 例1: 完全なデプロイメントワークフロー

```bash
#!/bin/bash
# Lambda関数の完全なデプロイメントスクリプト

FUNCTION_NAME="data-processor"
ROLE_ARN="arn:aws:iam::123456789012:role/lambda-execution-role"
RUNTIME="python3.11"
HANDLER="app.handler"

# 1. コードをパッケージング
echo "コードをパッケージング中..."
cd src/
zip -r ../function.zip .
cd ..

# 2. 関数が存在するか確認
if aws lambda get-function --function-name $FUNCTION_NAME 2>/dev/null; then
    echo "既存の関数を更新中..."
    
    # コードを更新
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://function.zip
    
    # 設定が安定するまで待機
    aws lambda wait function-updated \
        --function-name $FUNCTION_NAME
    
    # 設定を更新
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --handler $HANDLER \
        --memory-size 512 \
        --timeout 60 \
        --environment Variables={ENV=production,LOG_LEVEL=INFO}
    
    # 設定更新の完了を待機
    aws lambda wait function-updated \
        --function-name $FUNCTION_NAME
    
    # 新しいバージョンを公開
    VERSION=$(aws lambda publish-version \
        --function-name $FUNCTION_NAME \
        --description "デプロイ $(date +%Y-%m-%d-%H:%M:%S)" \
        --query 'Version' \
        --output text)
    
    echo "バージョン $VERSION が公開されました"
    
    # productionエイリアスを更新
    aws lambda update-alias \
        --function-name $FUNCTION_NAME \
        --name production \
        --function-version $VERSION
    
else
    echo "新しい関数を作成中..."
    
    # 関数を作成
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --role $ROLE_ARN \
        --handler $HANDLER \
        --zip-file fileb://function.zip \
        --memory-size 512 \
        --timeout 60 \
        --environment Variables={ENV=production,LOG_LEVEL=INFO} \
        --description "データ処理用Lambda関数"
    
    # 関数が利用可能になるまで待機
    aws lambda wait function-active \
        --function-name $FUNCTION_NAME
    
    # 初回バージョンを公開
    VERSION=$(aws lambda publish-version \
        --function-name $FUNCTION_NAME \
        --description "初回デプロイ" \
        --query 'Version' \
        --output text)
    
    # productionエイリアスを作成
    aws lambda create-alias \
        --function-name $FUNCTION_NAME \
        --name production \
        --function-version $VERSION
fi

echo "デプロイ完了!"
```

### 例2: カナリアデプロイメント

```bash
#!/bin/bash
# カナリアデプロイメントで新バージョンを段階的にリリース

FUNCTION_NAME="my-function"
NEW_VERSION="8"
OLD_VERSION="7"

echo "カナリアデプロイメントを開始..."

# ステップ1: 10%のトラフィックを新バージョンに
echo "10%のトラフィックを新バージョンに振り分け..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $OLD_VERSION \
    --routing-config AdditionalVersionWeights={"$NEW_VERSION"=0.1}

echo "10分間モニタリング..."
sleep 600

# ステップ2: 50%に増加
echo "50%のトラフィックを新バージョンに振り分け..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $OLD_VERSION \
    --routing-config AdditionalVersionWeights={"$NEW_VERSION"=0.5}

echo "10分間モニタリング..."
sleep 600

# ステップ3: 100%に切り替え
echo "100%のトラフィックを新バージョンに切り替え..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $NEW_VERSION

echo "カナリアデプロイメント完了!"
```

### 例3: 複数環境の管理

```bash
#!/bin/bash
# 開発、ステージング、本番環境の管理

FUNCTION_NAME="my-api-function"

# 開発環境: $LATESTを使用
echo "=== 開発環境 ==="
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name dev \
    --function-version '$LATEST' \
    2>/dev/null || \
aws lambda create-alias \
    --function-name $FUNCTION_NAME \
    --name dev \
    --function-version '$LATEST'

# ステージング環境: 最新の公開バージョン
echo "=== ステージング環境 ==="
LATEST_VERSION=$(aws lambda publish-version \
    --function-name $FUNCTION_NAME \
    --query 'Version' \
    --output text)

aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name staging \
    --function-version $LATEST_VERSION \
    2>/dev/null || \
aws lambda create-alias \
    --function-name $FUNCTION_NAME \
    --name staging \
    --function-version $LATEST_VERSION

# 本番環境: 手動で承認されたバージョン
echo "=== 本番環境 ==="
read -p "本番環境にバージョン $LATEST_VERSION をデプロイしますか？ (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    aws lambda update-alias \
        --function-name $FUNCTION_NAME \
        --name production \
        --function-version $LATEST_VERSION
    echo "本番環境が更新されました"
else
    echo "本番環境の更新がスキップされました"
fi
```

### 例4: 環境変数の動的更新

```bash
#!/bin/bash
# 環境変数を動的に更新するスクリプト

FUNCTION_NAME="my-function"

# 現在の設定をバックアップ
echo "現在の設定をバックアップ中..."
aws lambda get-function-configuration \
    --function-name $FUNCTION_NAME > backup-config.json

# 新しい環境変数を設定
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --environment Variables={\
DB_HOST=prod-db.example.com,\
DB_PORT=5432,\
DB_NAME=production,\
REDIS_HOST=prod-redis.example.com,\
REDIS_PORT=6379,\
API_ENDPOINT=https://api.example.com,\
LOG_LEVEL=INFO,\
REGION=ap-northeast-1\
}

# 更新完了を待機
aws lambda wait function-updated \
    --function-name $FUNCTION_NAME

echo "環境変数が更新されました"

# 新しい設定を表示
aws lambda get-function-configuration \
    --function-name $FUNCTION_NAME \
    --query 'Environment.Variables'
```

### 例5: 一括関数管理

```bash
#!/bin/bash
# 複数の関数を一括管理

# すべてのPython 3.9関数をPython 3.11にアップグレード
echo "Python 3.9関数を検索中..."
OLD_RUNTIME_FUNCTIONS=$(aws lambda list-functions \
    --query 'Functions[?Runtime==`python3.9`].FunctionName' \
    --output text)

for FUNCTION in $OLD_RUNTIME_FUNCTIONS; do
    echo "関数 $FUNCTION を更新中..."
    aws lambda update-function-configuration \
        --function-name $FUNCTION \
        --runtime python3.11
    
    # 各関数の更新完了を待機
    aws lambda wait function-updated \
        --function-name $FUNCTION
done

echo "すべての関数が更新されました"
```

### 例6: レイヤーを含む関数のデプロイ

```bash
#!/bin/bash
# レイヤーを使用した関数のデプロイメント

FUNCTION_NAME="data-analyzer"
LAYER_NAME="numpy-pandas-layer"

# ステップ1: レイヤーを作成
echo "レイヤーを作成中..."
cd layer/
zip -r layer.zip python/
cd ..

LAYER_VERSION_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --description "NumPy and Pandas libraries" \
    --zip-file fileb://layer/layer.zip \
    --compatible-runtimes python3.11 \
    --query 'LayerVersionArn' \
    --output text)

echo "レイヤーが作成されました: $LAYER_VERSION_ARN"

# ステップ2: 関数コードをパッケージング
echo "関数コードをパッケージング中..."
cd function/
zip -r function.zip .
cd ..

# ステップ3: レイヤーを使用して関数を作成または更新
if aws lambda get-function --function-name $FUNCTION_NAME 2>/dev/null; then
    echo "既存の関数を更新中..."
    
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://function/function.zip
    
    aws lambda wait function-updated \
        --function-name $FUNCTION_NAME
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --layers $LAYER_VERSION_ARN
else
    echo "新しい関数を作成中..."
    
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.11 \
        --role arn:aws:iam::123456789012:role/lambda-execution-role \
        --handler app.handler \
        --zip-file fileb://function/function.zip \
        --layers $LAYER_VERSION_ARN \
        --memory-size 1024 \
        --timeout 300
fi

echo "デプロイ完了!"
```

### 例7: ロールバック処理

```bash
#!/bin/bash
# 問題が発生した場合のロールバック

FUNCTION_NAME="my-function"

# 現在のproductionエイリアスの情報を取得
echo "現在の本番バージョンを確認中..."
CURRENT_VERSION=$(aws lambda get-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --query 'FunctionVersion' \
    --output text)

echo "現在のバージョン: $CURRENT_VERSION"

# 利用可能なバージョン一覧を表示
echo "利用可能なバージョン:"
aws lambda list-versions-by-function \
    --function-name $FUNCTION_NAME \
    --query 'Versions[?Version!=`$LATEST`].[Version,Description,LastModified]' \
    --output table

# ロールバック先のバージョンを入力
read -p "ロールバック先のバージョンを入力してください: " ROLLBACK_VERSION

# ロールバック実行
echo "バージョン $ROLLBACK_VERSION にロールバック中..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $ROLLBACK_VERSION

echo "ロールバック完了!"

# ロールバック後の確認
aws lambda get-alias \
    --function-name $FUNCTION_NAME \
    --name production
```

### 例8: タグベースの管理

```bash
#!/bin/bash
# タグを使用した関数の管理

# 特定のチームのすべての関数にタグを追加
TEAM="backend"

# チーム名を含む関数を検索
FUNCTIONS=$(aws lambda list-functions \
    --query "Functions[?contains(FunctionName, 'backend-')].FunctionName" \
    --output text)

for FUNCTION in $FUNCTIONS; do
    echo "関数 $FUNCTION にタグを追加中..."
    
    FUNCTION_ARN=$(aws lambda get-function \
        --function-name $FUNCTION \
        --query 'Configuration.FunctionArn' \
        --output text)
    
    aws lambda tag-resource \
        --resource $FUNCTION_ARN \
        --tags Team=$TEAM,ManagedBy=aws-cli,Environment=production
done

echo "タグ付けが完了しました"

# タグでフィルタリング（Cost Explorerなどで使用可能）
echo "すべての関数のタグを確認:"
for FUNCTION in $FUNCTIONS; do
    echo "=== $FUNCTION ==="
    FUNCTION_ARN=$(aws lambda get-function \
        --function-name $FUNCTION \
        --query 'Configuration.FunctionArn' \
        --output text)
    
    aws lambda list-tags \
        --resource $FUNCTION_ARN
done
```

---

## ベストプラクティス

### 1. バージョン管理戦略

```bash
# 本番環境では必ずバージョンを使用
# - $LATESTは開発環境のみで使用
# - productionエイリアスは常にバージョン番号を指定
# - stagingエイリアスで新バージョンをテスト

# 推奨される命名規則
# - dev: $LATEST（開発中のコード）
# - staging: 最新の公開バージョン（テスト用）
# - production: 安定したバージョン（本番用）
```

### 2. デプロイメント前のチェック

```bash
#!/bin/bash
# デプロイ前のバリデーション

FUNCTION_NAME="my-function"

# 関数が存在するか確認
if ! aws lambda get-function --function-name $FUNCTION_NAME &>/dev/null; then
    echo "エラー: 関数が見つかりません"
    exit 1
fi

# ZIPファイルのサイズを確認（50MB制限）
ZIP_SIZE=$(stat -f%z function.zip)
if [ $ZIP_SIZE -gt 52428800 ]; then
    echo "警告: ZIPファイルが50MBを超えています"
    echo "S3経由でのアップロードを検討してください"
fi

# IAMロールの存在確認
ROLE_ARN=$(aws lambda get-function-configuration \
    --function-name $FUNCTION_NAME \
    --query 'Role' \
    --output text)

if ! aws iam get-role --role-name $(basename $ROLE_ARN) &>/dev/null; then
    echo "エラー: IAMロールが見つかりません"
    exit 1
fi

echo "すべてのチェックが完了しました"
```

### 3. モニタリングとアラート

```bash
# デプロイ後にメトリクスを確認
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=my-function \
    --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

---

## トラブルシューティング

### よくあるエラーと対処法

**1. ResourceConflictException: 関数の更新中**
```bash
# 解決策: 関数の状態が安定するまで待機
aws lambda wait function-updated --function-name my-function
```

**2. InvalidParameterValueException: ZIPファイルが大きすぎる**
```bash
# 解決策: S3経由でアップロード
aws s3 cp function.zip s3://my-bucket/
aws lambda update-function-code \
    --function-name my-function \
    --s3-bucket my-bucket \
    --s3-key function.zip
```

**3. エイリアスが指すバージョンを削除できない**
```bash
# 解決策: まずエイリアスを削除またはバージョンを変更
aws lambda delete-alias --function-name my-function --name staging
```

---

## 関連リソース

- [Lambda実行とログ確認](./invocation.md)
- [Lambdaログ管理](./logs.md)
- [IAMロール管理](../04_iam/role_management.md)
- [AWS Lambda公式ドキュメント](https://docs.aws.amazon.com/lambda/)
