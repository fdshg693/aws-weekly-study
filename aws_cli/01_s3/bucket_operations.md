# S3 バケット操作

## 目次
- [バケットの作成](#バケットの作成)
- [バケットの一覧表示](#バケットの一覧表示)
- [バケットの削除](#バケットの削除)
- [バケットのロケーション確認](#バケットのロケーション確認)
- [バケットのバージョニング](#バケットのバージョニング)
- [バケットの暗号化](#バケットの暗号化)
- [ライフサイクルルール](#ライフサイクルルール)
- [バケットタグ](#バケットタグ)
- [バケットポリシー](#バケットポリシー)
- [CORS設定](#cors設定)
- [ウェブサイト設定](#ウェブサイト設定)
- [ログ設定](#ログ設定)

---

## バケットの作成

S3バケットはオブジェクトを格納するための基本的なコンテナです。バケット名はグローバルに一意である必要があり、作成後は変更できません。

### 基本的なバケット作成（s3コマンド）

`aws s3 mb`（make bucket）コマンドは、シンプルで直感的なバケット作成方法です。

```bash
# 基本的な作成（デフォルトリージョン）
aws s3 mb s3://my-bucket-name

# 実行結果:
# make_bucket: my-bucket-name

# 特定のリージョンに作成
aws s3 mb s3://my-bucket-name --region ap-northeast-1

# 複数のバケットを一度に作成
for env in dev staging prod; do
  aws s3 mb s3://myapp-${env}-data --region ap-northeast-1
done
```

**使用ケース:**
- 開発中の簡単なテスト用バケット作成
- スクリプトでの複数バケット作成
- 基本的な要件のみのシンプルなバケット

### s3api を使用した詳細なバケット作成

`aws s3api create-bucket`は、より細かい制御とオプション指定が可能です。

```bash
# 基本的な作成（東京リージョン）
aws s3api create-bucket \
  --bucket my-bucket-name \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

# 実行結果:
# {
#     "Location": "http://my-bucket-name.s3.amazonaws.com/"
# }

# us-east-1 の場合は LocationConstraint 不要
aws s3api create-bucket \
  --bucket my-bucket-name \
  --region us-east-1

# ACL を指定して作成（従来の方法）
aws s3api create-bucket \
  --bucket my-bucket-name \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1 \
  --acl private

# ACLオプション:
# - private: デフォルト、所有者のみフルコントロール
# - public-read: 誰でも読み取り可能（非推奨）
# - public-read-write: 誰でも読み書き可能（非推奨）
# - authenticated-read: 認証されたAWSユーザーが読み取り可能

# オブジェクト所有権を指定して作成（推奨）
aws s3api create-bucket \
  --bucket my-bucket-name \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1 \
  --object-ownership BucketOwnerEnforced

# オブジェクト所有権オプション:
# - BucketOwnerEnforced: ACLを無効化（推奨、2023年4月以降のデフォルト）
# - BucketOwnerPreferred: バケット所有者がオブジェクトを所有
# - ObjectWriter: アップロードしたアカウントが所有
```

### 作成時のセキュリティ設定

```bash
# セキュアなバケットを作成（推奨設定）
BUCKET_NAME="secure-app-data"
REGION="ap-northeast-1"

# 1. バケット作成
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION \
  --object-ownership BucketOwnerEnforced

# 2. パブリックアクセスブロック（即座に適用）
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "セキュアなバケット $BUCKET_NAME を作成しました"
```

### バケット作成の検証

```bash
# バケットが正常に作成されたか確認
aws s3api head-bucket --bucket my-bucket-name

# エラーがなければ作成成功（出力なし）
# バケットが存在しない場合: 404エラー
# アクセス権限がない場合: 403エラー

# バケットの存在確認（スクリプト用）
if aws s3api head-bucket --bucket my-bucket-name 2>/dev/null; then
  echo "バケットは既に存在します"
else
  echo "バケットは存在しません"
fi

# バケットの詳細情報を確認
aws s3api list-buckets --query "Buckets[?Name=='my-bucket-name']"
```

### エラーハンドリング

```bash
# バケット作成時のエラーハンドリング
BUCKET_NAME="my-new-bucket"
REGION="ap-northeast-1"

if aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION 2>&1 | \
  grep -q "BucketAlreadyExists\|BucketAlreadyOwnedByYou"; then
  echo "エラー: バケット名は既に使用されています"
  exit 1
elif aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
  echo "成功: バケットを作成しました"
else
  echo "エラー: バケット作成に失敗しました"
  exit 1
fi
```

### バケット作成時の注意点とベストプラクティス

**命名規則:**
- バケット名はグローバルで一意である必要があります（全AWSアカウント間で）
- バケット名は3〜63文字で、小文字、数字、ハイフンのみ使用可能
- バケット名はDNS準拠である必要があります（ピリオドの使用は非推奨）
- 先頭と末尾は小文字の英字または数字である必要があります
- IPアドレス形式（例: 192.168.1.1）は使用不可
- "xn--"で始まる名前は使用不可（国際化ドメイン名用）
- "-s3alias"で終わる名前は使用不可

**推奨される命名規則の例:**
```bash
# 環境別
myapp-prod-data
myapp-dev-data
myapp-staging-logs

# 用途別
company-backups
project-uploads
analytics-data-warehouse

# リージョン別（必要な場合）
myapp-us-east-1-data
myapp-ap-northeast-1-data
```

**リージョン選択の考慮事項:**
- us-east-1 以外のリージョンでは `LocationConstraint` が必須
- レイテンシーを最小化するため、ユーザーに近いリージョンを選択
- データ主権やコンプライアンス要件を考慮
- コストはリージョンによって異なる

**セキュリティのベストプラクティス:**
- 作成直後にパブリックアクセスブロックを有効化
- オブジェクト所有権は `BucketOwnerEnforced` を使用（ACL無効化）
- バージョニングと暗号化を早期に設定
- タグを使用してリソース管理とコスト配分を実施

---

## バケットの一覧表示

S3バケットやオブジェクトの一覧を表示することで、リソースの確認や管理が可能です。

### すべてのバケットを一覧表示

```bash
# シンプルな一覧表示
aws s3 ls

# 実行結果例:
# 2023-01-15 10:30:45 my-first-bucket
# 2023-02-20 14:22:10 my-second-bucket
# 2023-03-05 09:15:33 my-third-bucket

# 出力フォーマット:
# [作成日時] [バケット名]
```

### バケット内のオブジェクトを一覧表示

```bash
# 特定のバケット内のオブジェクトを一覧表示
aws s3 ls s3://my-bucket-name

# 実行結果例:
#                            PRE logs/
# 2024-01-15 10:30:45      12345 document.pdf
# 2024-01-16 14:22:10    8765432 video.mp4

# 出力フォーマット:
# PRE: プレフィックス（フォルダ）
# [日時] [サイズ] [ファイル名]

# プレフィックス（フォルダ）を指定して一覧表示
aws s3 ls s3://my-bucket-name/logs/

# 特定の日付パターンで検索
aws s3 ls s3://my-bucket-name/logs/2024/01/

# 再帰的に全ファイルを表示
aws s3 ls s3://my-bucket-name --recursive

# 実行結果例:
# 2024-01-15 10:30:45      12345 logs/app.log
# 2024-01-15 11:20:33       5678 logs/error.log
# 2024-01-16 09:15:22     123456 data/users.csv

# 人間が読みやすい形式で表示
aws s3 ls s3://my-bucket-name --human-readable

# 実行結果例:
# 2024-01-15 10:30:45   12.1 KiB document.pdf
# 2024-01-16 14:22:10    8.4 MiB video.mp4

# 合計サイズを表示
aws s3 ls s3://my-bucket-name --summarize --recursive

# 実行結果例:
# Total Objects: 150
# Total Size: 2.5 GiB
```

### フィルタリングと検索

```bash
# 特定の拡張子のファイルのみ表示
aws s3 ls s3://my-bucket-name --recursive | grep "\.pdf$"

# 特定のパターンに一致するファイルを検索
aws s3 ls s3://my-bucket-name/logs/ --recursive | grep "2024-01"

# サイズが大きいファイルを表示（1MB以上）
aws s3 ls s3://my-bucket-name --recursive --human-readable | \
  awk '$3 ~ /MiB|GiB/ {print $0}'

# 最新のファイルを10個表示
aws s3 ls s3://my-bucket-name --recursive | sort -k1,2 -r | head -10

# ファイル数とサイズを集計
aws s3 ls s3://my-bucket-name --recursive --summarize | tail -2
```

### s3api を使用した詳細な一覧表示

```bash
# すべてのバケットの詳細情報
aws s3api list-buckets

# 実行結果例:
# {
#     "Buckets": [
#         {
#             "Name": "my-first-bucket",
#             "CreationDate": "2023-01-15T10:30:45+00:00"
#         },
#         {
#             "Name": "my-second-bucket",
#             "CreationDate": "2023-02-20T14:22:10+00:00"
#         }
#     ],
#     "Owner": {
#         "DisplayName": "my-account",
#         "ID": "abc123..."
#     }
# }

# 所有者情報を表示
aws s3api list-buckets --query "Owner"

# バケット名のみを表示
aws s3api list-buckets --query "Buckets[].Name" --output text

# 特定の条件でフィルタリング（jq使用）
aws s3api list-buckets | jq '.Buckets[] | select(.Name | startswith("prod-"))'

# 作成日時でソート
aws s3api list-buckets | jq '.Buckets | sort_by(.CreationDate)'

# 最近作成されたバケットを5つ表示
aws s3api list-buckets | jq '.Buckets | sort_by(.CreationDate) | reverse | .[0:5]'

# バケット数をカウント
aws s3api list-buckets --query "length(Buckets)"
```

### バケット内オブジェクトの詳細一覧

```bash
# バケット内のオブジェクト一覧（最大1000件）
aws s3api list-objects-v2 --bucket my-bucket-name

# 特定のプレフィックスのオブジェクト
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --prefix "logs/2024/"

# キー名のみを表示
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --query "Contents[].Key" \
  --output text

# サイズでソート（大きい順）
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --query "reverse(sort_by(Contents, &Size))[0:10].{Key:Key, Size:Size}"

# 最終更新日でソート
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --query "reverse(sort_by(Contents, &LastModified))[0:10].{Key:Key, Date:LastModified}"

# 特定のサイズ以上のファイルを検索（10MB以上）
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --query "Contents[?Size > \`10485760\`].{Key:Key, Size:Size}" \
  --output table
```

### ページネーション処理

```bash
# すべてのオブジェクトを取得（1000件以上でも自動ページング）
aws s3api list-objects-v2 \
  --bucket my-bucket-name \
  --max-items 10000

# 手動でページング
TOKEN=""
while : ; do
  if [ -z "$TOKEN" ]; then
    RESULT=$(aws s3api list-objects-v2 --bucket my-bucket-name)
  else
    RESULT=$(aws s3api list-objects-v2 --bucket my-bucket-name --continuation-token "$TOKEN")
  fi
  
  # オブジェクトを処理
  echo "$RESULT" | jq -r '.Contents[].Key'
  
  # 次のトークンを取得
  TOKEN=$(echo "$RESULT" | jq -r '.NextContinuationToken // empty')
  
  # トークンがなければ終了
  [ -z "$TOKEN" ] && break
done
```

### バケットとリージョンの一覧

```bash
# すべてのバケットとそのリージョンを表示
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location \
    --bucket $bucket \
    --query "LocationConstraint" \
    --output text 2>/dev/null)
  
  # us-east-1 の場合は "None" が返される
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  echo "$bucket: $region"
done

# 結果をCSV形式で出力
echo "BucketName,Region"
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location \
    --bucket $bucket \
    --query "LocationConstraint" \
    --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  echo "$bucket,$region"
done > buckets.csv
```

### 実用的なリスト作成スクリプト

```bash
#!/bin/bash
# すべてのバケットの詳細レポートを生成

echo "=== S3 バケット詳細レポート ==="
echo "生成日時: $(date)"
echo ""

for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  echo "バケット名: $bucket"
  
  # リージョン
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  echo "  リージョン: $region"
  
  # オブジェクト数とサイズ
  summary=$(aws s3 ls s3://$bucket --recursive --summarize 2>/dev/null | tail -2)
  echo "  $summary"
  
  # バージョニング
  versioning=$(aws s3api get-bucket-versioning --bucket $bucket --query "Status" --output text 2>/dev/null)
  echo "  バージョニング: ${versioning:-無効}"
  
  # 暗号化
  encryption=$(aws s3api get-bucket-encryption --bucket $bucket --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" --output text 2>/dev/null)
  echo "  暗号化: ${encryption:-未設定}"
  
  echo ""
done
```

**使用ケース:**
- 定期的なバケットの棚卸し
- ストレージコストの分析
- セキュリティ監査の準備
- 大容量ファイルの特定
- 古いファイルのクリーンアップ計画

---

## バケットの削除

バケットを削除する前に、中身が空であることを確認する必要があります。バージョニングが有効な場合は、すべてのバージョンと削除マーカーも削除する必要があります。

### 空のバケットを削除

```bash
# 空のバケットの削除
aws s3 rb s3://my-bucket-name

# 実行結果:
# remove_bucket: my-bucket-name

# バケットが空でない場合のエラー:
# remove_bucket failed: s3://my-bucket-name An error occurred (BucketNotEmpty) when calling the DeleteBucket operation: The bucket you tried to delete is not empty

# エラーを抑制（バケットが存在しない場合でもエラーを表示しない）
aws s3 rb s3://my-bucket-name 2>/dev/null || true

# 削除前に確認
read -p "バケット 's3://my-bucket-name' を削除しますか? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
  aws s3 rb s3://my-bucket-name
  echo "バケットを削除しました"
else
  echo "削除をキャンセルしました"
fi
```

### バケット内のオブジェクトごと削除

```bash
# --force オプションで中身ごと削除
aws s3 rb s3://my-bucket-name --force

# 実行内容:
# 1. バケット内のすべてのオブジェクトを削除
# 2. バケットを削除

# 削除前にサイズを確認
echo "削除対象のバケット情報:"
aws s3 ls s3://my-bucket-name --recursive --summarize
echo ""
read -p "本当に削除しますか? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
  echo "削除中..."
  aws s3 rb s3://my-bucket-name --force
  echo "完了しました"
else
  echo "削除をキャンセルしました"
fi

# ドライラン（実際には削除しない）
echo "以下のファイルが削除されます:"
aws s3 ls s3://my-bucket-name --recursive
```

### バージョニング有効なバケットの完全削除

バージョニングが有効な場合、`--force`オプションは現在のバージョンのみを削除し、古いバージョンや削除マーカーは残ります。

```bash
# s3api を使用してバケットを削除
aws s3api delete-bucket --bucket my-bucket-name

# バージョニング有効な場合は全バージョンを削除する必要がある
# エラー例:
# An error occurred (BucketNotEmpty) when calling the DeleteBucket operation: The bucket you tried to delete is not empty. You must delete all versions in the bucket.
```

#### 完全削除スクリプト（バージョン対応）

```bash
#!/bin/bash
# バージョニング有効なバケットを完全に削除

BUCKET_NAME="my-versioned-bucket"

echo "バケット '$BUCKET_NAME' の完全削除を開始します..."

# 1. すべてのオブジェクトバージョンを削除
echo "オブジェクトバージョンを削除中..."
aws s3api list-object-versions \
  --bucket $BUCKET_NAME \
  --output json \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' | \
  jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
  while read -r args; do
    eval aws s3api delete-object --bucket $BUCKET_NAME $args
  done

# 2. すべての削除マーカーを削除
echo "削除マーカーを削除中..."
aws s3api list-object-versions \
  --bucket $BUCKET_NAME \
  --output json \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' | \
  jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
  while read -r args; do
    eval aws s3api delete-object --bucket $BUCKET_NAME $args
  done

# 3. バケットを削除
echo "バケットを削除中..."
aws s3api delete-bucket --bucket $BUCKET_NAME

echo "完了: バケット '$BUCKET_NAME' を完全に削除しました"
```

### 複数のバケットを削除

```bash
# パターンに一致するバケットを削除（危険な操作なので注意）
for bucket in $(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'test-')].Name" --output text); do
  echo "削除中: $bucket"
  aws s3 rb s3://$bucket --force
done

# 環境別の削除（開発環境のみ）
for bucket in $(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'dev-')].Name" --output text); do
  echo "バケット: $bucket"
  read -p "削除しますか? (yes/no): " confirm
  if [ "$confirm" = "yes" ]; then
    aws s3 rb s3://$bucket --force
    echo "削除しました: $bucket"
  fi
done
```

### 安全な削除手順（本番環境向け）

```bash
#!/bin/bash
# 安全なバケット削除スクリプト

BUCKET_NAME="${1}"

if [ -z "$BUCKET_NAME" ]; then
  echo "使用方法: $0 <bucket-name>"
  exit 1
fi

# 1. バケットの存在確認
if ! aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
  echo "エラー: バケット '$BUCKET_NAME' は存在しません"
  exit 1
fi

# 2. バケット情報を表示
echo "=== バケット情報 ==="
echo "名前: $BUCKET_NAME"

# リージョン
region=$(aws s3api get-bucket-location --bucket $BUCKET_NAME --query "LocationConstraint" --output text)
echo "リージョン: ${region:-us-east-1}"

# バージョニング
versioning=$(aws s3api get-bucket-versioning --bucket $BUCKET_NAME --query "Status" --output text)
echo "バージョニング: ${versioning:-無効}"

# オブジェクト数とサイズ
echo ""
echo "=== コンテンツ情報 ==="
aws s3 ls s3://$BUCKET_NAME --recursive --summarize 2>/dev/null | tail -2

# 3. 最終確認
echo ""
echo "警告: この操作は取り消せません！"
read -p "バケット名を入力して削除を確認してください: " confirm

if [ "$confirm" != "$BUCKET_NAME" ]; then
  echo "バケット名が一致しません。削除を中止します。"
  exit 1
fi

# 4. 削除実行
echo ""
echo "削除を開始します..."

if [ "$versioning" = "Enabled" ]; then
  echo "バージョニングが有効です。すべてのバージョンを削除します..."
  
  # バージョン削除
  aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --output json | \
    jq -r '.Versions[]?, .DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
    while read -r args; do
      eval aws s3api delete-object --bucket $BUCKET_NAME $args
    done
  
  aws s3api delete-bucket --bucket $BUCKET_NAME
else
  aws s3 rb s3://$BUCKET_NAME --force
fi

echo ""
echo "完了: バケット '$BUCKET_NAME' を削除しました"
```

### 削除の検証

```bash
# バケットが削除されたことを確認
if ! aws s3api head-bucket --bucket my-bucket-name 2>/dev/null; then
  echo "確認: バケットは正常に削除されました"
else
  echo "エラー: バケットはまだ存在します"
fi

# すべてのバケットリストで確認
aws s3 ls | grep -q "my-bucket-name" && echo "存在する" || echo "削除済み"
```

### エラーハンドリングと対処法

```bash
# よくあるエラーと対処法

# エラー1: BucketNotEmpty
# 対処: --force オプションを使用するか、手動でオブジェクトを削除

# エラー2: AccessDenied
# 対処: 削除権限を確認
aws s3api get-bucket-policy --bucket my-bucket-name
aws s3api get-bucket-acl --bucket my-bucket-name

# エラー3: バージョニング有効時の削除失敗
# 対処: すべてのバージョンと削除マーカーを削除
BUCKET="my-bucket"

# バージョン数を確認
version_count=$(aws s3api list-object-versions --bucket $BUCKET --query 'length(Versions)')
marker_count=$(aws s3api list-object-versions --bucket $BUCKET --query 'length(DeleteMarkers)')

echo "オブジェクトバージョン: $version_count"
echo "削除マーカー: $marker_count"

# エラー4: ライフサイクルポリシーによるロック
# 対処: ライフサイクルポリシーを先に削除
aws s3api delete-bucket-lifecycle --bucket my-bucket-name

# エラー5: オブジェクトロック有効
# 対処: オブジェクトロックの保持期間が過ぎるまで待つか、
#       Governance モードの場合は特別な権限で削除
```

### 削除時のベストプラクティス

**安全対策:**
1. 削除前に必ずバケットの内容を確認
2. 本番環境では二段階確認を実施
3. 削除ログを記録
4. 重要なバケットには削除防止タグを設定

```bash
# 削除防止タグの設定
aws s3api put-bucket-tagging \
  --bucket important-bucket \
  --tagging 'TagSet=[{Key=DoNotDelete,Value=true}]'

# 削除前のタグチェック
check_tag=$(aws s3api get-bucket-tagging \
  --bucket $BUCKET_NAME \
  --query "TagSet[?Key=='DoNotDelete'].Value" \
  --output text 2>/dev/null)

if [ "$check_tag" = "true" ]; then
  echo "エラー: このバケットは削除防止タグが設定されています"
  exit 1
fi
```

**コスト削減のための削除:**
- 未使用のバケットを定期的に削除
- テスト用バケットの自動削除スクリプトを作成
- 不完全なマルチパートアップロードを削除

**削除の代替案:**
- 完全削除の代わりにライフサイクルポリシーで自動削除
- バケットの内容のみを削除してバケット自体は保持
- バケット名を再利用する場合は即座に再作成

---

## バケットのロケーション確認

バケットが配置されているAWSリージョンを確認することは、レイテンシー最適化やコンプライアンス確認に重要です。

### 基本的なロケーション確認

```bash
# バケットのリージョンを確認
aws s3api get-bucket-location --bucket my-bucket-name

# 出力例（東京リージョン）:
# {
#     "LocationConstraint": "ap-northeast-1"
# }

# 出力例（バージニア北部リージョン）:
# {
#     "LocationConstraint": null
# }
# ※ us-east-1 の場合は null または空

# リージョン名のみを取得
aws s3api get-bucket-location \
  --bucket my-bucket-name \
  --query "LocationConstraint" \
  --output text

# us-east-1 の場合は "None" が返される
```

### すべてのバケットのリージョンを確認

```bash
# すべてのバケットのリージョンを一覧表示
for bucket in $(aws s3 ls | awk '{print $3}'); do
  location=$(aws s3api get-bucket-location \
    --bucket $bucket \
    --query 'LocationConstraint' \
    --output text 2>/dev/null)
  
  # us-east-1 の場合は None が返されるので変換
  location=${location:-us-east-1}
  [ "$location" = "None" ] && location="us-east-1"
  
  echo "$bucket: $location"
done

# 実行結果例:
# my-prod-bucket: ap-northeast-1
# my-dev-bucket: us-west-2
# my-backup-bucket: us-east-1
```

### リージョン別バケット数の集計

```bash
# リージョンごとにバケット数を集計
declare -A region_count

for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  ((region_count[$region]++))
done

echo "=== リージョン別バケット数 ==="
for region in "${!region_count[@]}"; do
  echo "$region: ${region_count[$region]} バケット"
done | sort

# 実行結果例:
# ap-northeast-1: 15 バケット
# us-east-1: 8 バケット
# us-west-2: 3 バケット
```

### CSV形式でエクスポート

```bash
# バケット情報をCSV形式で出力
echo "BucketName,Region,CreationDate"

aws s3api list-buckets --query "Buckets[].[Name,CreationDate]" --output text | \
while read -r bucket creation_date; do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  echo "$bucket,$region,$creation_date"
done > bucket_locations.csv

echo "CSVファイルを作成しました: bucket_locations.csv"
```

### 詳細な地理情報レポート

```bash
#!/bin/bash
# バケットの詳細な地理情報レポート

# リージョンの日本語名マッピング
declare -A region_names=(
  ["us-east-1"]="バージニア北部"
  ["us-east-2"]="オハイオ"
  ["us-west-1"]="カリフォルニア北部"
  ["us-west-2"]="オレゴン"
  ["ap-northeast-1"]="東京"
  ["ap-northeast-2"]="ソウル"
  ["ap-northeast-3"]="大阪"
  ["ap-southeast-1"]="シンガポール"
  ["ap-southeast-2"]="シドニー"
  ["eu-west-1"]="アイルランド"
  ["eu-central-1"]="フランクフルト"
)

echo "=== S3バケット地理情報レポート ==="
echo "生成日時: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  region_name=${region_names[$region]:-$region}
  
  echo "バケット: $bucket"
  echo "  リージョン: $region ($region_name)"
  
  # 作成日時
  creation_date=$(aws s3api list-buckets --query "Buckets[?Name=='$bucket'].CreationDate" --output text)
  echo "  作成日時: $creation_date"
  
  echo ""
done
```

### 特定リージョンのバケットを抽出

```bash
# 東京リージョンのバケットのみ表示
TARGET_REGION="ap-northeast-1"

echo "=== $TARGET_REGION のバケット一覧 ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  if [ "$region" = "$TARGET_REGION" ]; then
    echo "- $bucket"
  fi
done

# 複数リージョンのバケットを抽出
TARGET_REGIONS=("ap-northeast-1" "ap-northeast-3" "us-west-2")

echo "=== 対象リージョンのバケット一覧 ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  for target in "${TARGET_REGIONS[@]}"; do
    if [ "$region" = "$target" ]; then
      echo "$bucket ($region)"
      break
    fi
  done
done
```

### エンドポイントURLの生成

```bash
# バケットのエンドポイントURLを取得
BUCKET_NAME="my-bucket-name"

region=$(aws s3api get-bucket-location --bucket $BUCKET_NAME --query "LocationConstraint" --output text)
region=${region:-us-east-1}
[ "$region" = "None" ] && region="us-east-1"

# パス形式のURL
echo "パス形式: https://s3.$region.amazonaws.com/$BUCKET_NAME"

# 仮想ホスト形式のURL
echo "仮想ホスト形式: https://$BUCKET_NAME.s3.$region.amazonaws.com"

# グローバルエンドポイント（自動的に正しいリージョンにリダイレクト）
echo "グローバルエンドポイント: https://$BUCKET_NAME.s3.amazonaws.com"

# ウェブサイトエンドポイント（ウェブサイトホスティング有効時）
if [ "$region" = "us-east-1" ]; then
  echo "ウェブサイトエンドポイント: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"
else
  echo "ウェブサイトエンドポイント: http://$BUCKET_NAME.s3-website-$region.amazonaws.com"
fi
```

### リージョン間のレイテンシー比較

```bash
#!/bin/bash
# 各リージョンのS3エンドポイントへのレイテンシーを測定

regions=(
  "us-east-1"
  "us-west-2"
  "ap-northeast-1"
  "ap-southeast-1"
  "eu-west-1"
)

echo "=== S3リージョンレイテンシー測定 ==="
echo ""

for region in "${regions[@]}"; do
  endpoint="s3.$region.amazonaws.com"
  
  # pingでレイテンシーを測定（3回）
  echo -n "$region: "
  ping -c 3 $endpoint 2>/dev/null | tail -1 | awk '{print $4}' | cut -d'/' -f2
done | sort -t':' -k2 -n

# 最速のリージョンを推奨
echo ""
echo "※ 最も低いレイテンシーのリージョンの使用を推奨します"
```

### バケット移行時のリージョン確認

```bash
# 移行元と移行先のリージョンを確認
SOURCE_BUCKET="old-bucket"
TARGET_BUCKET="new-bucket"

source_region=$(aws s3api get-bucket-location --bucket $SOURCE_BUCKET --query "LocationConstraint" --output text)
target_region=$(aws s3api get-bucket-location --bucket $TARGET_BUCKET --query "LocationConstraint" --output text)

source_region=${source_region:-us-east-1}
target_region=${target_region:-us-east-1}
[ "$source_region" = "None" ] && source_region="us-east-1"
[ "$target_region" = "None" ] && target_region="us-east-1"

echo "移行元: $SOURCE_BUCKET ($source_region)"
echo "移行先: $TARGET_BUCKET ($target_region)"

if [ "$source_region" != "$target_region" ]; then
  echo ""
  echo "警告: リージョンをまたぐ移行です"
  echo "- データ転送料金が発生します"
  echo "- 転送時間が長くなる可能性があります"
else
  echo ""
  echo "同一リージョン内の移行です（転送料金なし）"
fi
```

### 実用的な使用例

**コンプライアンス確認:**
```bash
# データレジデンシー要件の確認（日本国内のみ）
ALLOWED_REGIONS=("ap-northeast-1" "ap-northeast-3")

echo "=== データレジデンシーチェック ==="
violations=0

for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  # 許可されたリージョンかチェック
  is_allowed=false
  for allowed in "${ALLOWED_REGIONS[@]}"; do
    if [ "$region" = "$allowed" ]; then
      is_allowed=true
      break
    fi
  done
  
  if [ "$is_allowed" = false ]; then
    echo "違反: $bucket ($region)"
    ((violations++))
  fi
done

if [ $violations -eq 0 ]; then
  echo "すべてのバケットが要件を満たしています"
else
  echo ""
  echo "警告: $violations 個のバケットが要件を満たしていません"
fi
```

**コスト最適化:**
```bash
# 使用頻度の低いリージョンのバケットを特定
# （CloudWatchメトリクスと組み合わせることでより正確）

for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  region=$(aws s3api get-bucket-location --bucket $bucket --query "LocationConstraint" --output text 2>/dev/null)
  region=${region:-us-east-1}
  [ "$region" = "None" ] && region="us-east-1"
  
  # リージョンの料金情報（例）
  case $region in
    "us-east-1")
      cost="低コスト"
      ;;
    "ap-northeast-1"|"ap-northeast-3")
      cost="中コスト"
      ;;
    "ap-southeast-1"|"ap-southeast-2")
      cost="高コスト"
      ;;
    *)
      cost="不明"
      ;;
  esac
  
  echo "$bucket: $region ($cost)"
done
```

---

## バケットのバージョニング

バージョニングは、同じキーのオブジェクトの複数のバージョンを保持する機能です。誤削除や上書きからデータを保護し、以前のバージョンに復元できます。

### バージョニングの概要

**重要な特徴:**
- 有効化後は完全に無効化できない（一時停止のみ可能）
- 各バージョンに一意のバージョンIDが付与される
- 削除操作は削除マーカーを作成（実際には削除されない）
- バージョン数に応じてストレージコストが増加

**状態:**
- `未設定`: バージョニングが有効化されていない初期状態
- `Enabled`: バージョニング有効
- `Suspended`: バージョニング一時停止

### バージョニングの有効化

```bash
# バージョニングを有効化
aws s3api put-bucket-versioning \
  --bucket my-bucket-name \
  --versioning-configuration Status=Enabled

# 実行結果: 出力なし（成功時）

# 複数のバケットで一括有効化
for bucket in my-prod-bucket my-backup-bucket; do
  echo "バージョニングを有効化: $bucket"
  aws s3api put-bucket-versioning \
    --bucket $bucket \
    --versioning-configuration Status=Enabled
done

# 新規バケット作成と同時にバージョニング有効化
BUCKET_NAME="versioned-bucket"
REGION="ap-northeast-1"

aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

echo "バージョニング有効なバケットを作成しました"
```

### MFA削除の有効化

MFA削除を有効にすると、バージョンの削除やバージョニングの停止にMFA認証が必要になります。

```bash
# MFA削除を有効にしてバージョニングを設定
# ※ この操作にはルートアカウントの認証情報が必要

aws s3api put-bucket-versioning \
  --bucket my-bucket-name \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/root-account-mfa-device TOKENCODE"

# MFAデバイスのARN形式:
# arn:aws:iam::ACCOUNT-ID:mfa/DEVICE-NAME

# トークンコード: MFAデバイスに表示される6桁のコード
```

### バージョニングの一時停止

```bash
# バージョニングを一時停止
aws s3api put-bucket-versioning \
  --bucket my-bucket-name \
  --versioning-configuration Status=Suspended

# 一時停止の影響:
# - 新しいオブジェクトはバージョンIDが null になる
# - 既存のバージョンは保持される
# - 削除マーカーは作成され続ける

# MFA削除が有効な場合は一時停止にもMFAが必要
aws s3api put-bucket-versioning \
  --bucket my-bucket-name \
  --versioning-configuration Status=Suspended,MFADelete=Enabled \
  --mfa "arn:aws:iam::123456789012:mfa/root-account-mfa-device TOKENCODE"
```

### バージョニング状態の確認

```bash
# バージョニング状態を確認
aws s3api get-bucket-versioning --bucket my-bucket-name

# 出力例（有効時）:
# {
#     "Status": "Enabled",
#     "MFADelete": "Disabled"
# }

# 出力例（無効時）:
# {}
# ※ バージョニングが一度も有効化されていない場合は空

# 出力例（一時停止時）:
# {
#     "Status": "Suspended"
# }

# ステータスのみを取得
aws s3api get-bucket-versioning \
  --bucket my-bucket-name \
  --query "Status" \
  --output text

# バージョニング有効か判定（スクリプト用）
if [ "$(aws s3api get-bucket-versioning --bucket my-bucket-name --query 'Status' --output text)" = "Enabled" ]; then
  echo "バージョニングは有効です"
else
  echo "バージョニングは無効または一時停止中です"
fi
```

### すべてのバケットのバージョニング状態を確認

```bash
# すべてのバケットのバージョニング状態を一覧表示
echo "=== バケットのバージョニング状態 ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  status=$(aws s3api get-bucket-versioning --bucket $bucket --query "Status" --output text 2>/dev/null)
  status=${status:-無効}
  
  mfa_delete=$(aws s3api get-bucket-versioning --bucket $bucket --query "MFADelete" --output text 2>/dev/null)
  
  echo "$bucket: $status"
  if [ -n "$mfa_delete" ] && [ "$mfa_delete" != "None" ]; then
    echo "  MFA削除: $mfa_delete"
  fi
done

# バージョニング有効なバケットのみ表示
echo "=== バージョニング有効なバケット ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  status=$(aws s3api get-bucket-versioning --bucket $bucket --query "Status" --output text 2>/dev/null)
  if [ "$status" = "Enabled" ]; then
    echo "- $bucket"
  fi
done
```

### オブジェクトバージョンの一覧表示

```bash
# バケット内のすべてのオブジェクトバージョンを表示
aws s3api list-object-versions --bucket my-bucket-name

# 出力例:
# {
#     "Versions": [
#         {
#             "Key": "document.pdf",
#             "VersionId": "abc123...",
#             "IsLatest": true,
#             "LastModified": "2024-01-15T10:30:45.000Z",
#             "Size": 12345
#         },
#         {
#             "Key": "document.pdf",
#             "VersionId": "def456...",
#             "IsLatest": false,
#             "LastModified": "2024-01-10T09:20:30.000Z",
#             "Size": 11234
#         }
#     ],
#     "DeleteMarkers": [
#         {
#             "Key": "old-file.txt",
#             "VersionId": "ghi789...",
#             "IsLatest": true,
#             "LastModified": "2024-01-12T14:15:22.000Z"
#         }
#     ]
# }

# 特定のオブジェクトのバージョン履歴
aws s3api list-object-versions \
  --bucket my-bucket-name \
  --prefix "document.pdf" \
  --query "Versions[].[VersionId,LastModified,Size,IsLatest]" \
  --output table

# バージョン数をカウント
version_count=$(aws s3api list-object-versions \
  --bucket my-bucket-name \
  --query "length(Versions)")
  
delete_marker_count=$(aws s3api list-object-versions \
  --bucket my-bucket-name \
  --query "length(DeleteMarkers)")

echo "オブジェクトバージョン: $version_count"
echo "削除マーカー: $delete_marker_count"
```

### 特定バージョンの取得

```bash
# 最新バージョンを取得（通常の取得）
aws s3 cp s3://my-bucket-name/document.pdf ./document.pdf

# 特定のバージョンを取得
VERSION_ID="abc123..."
aws s3api get-object \
  --bucket my-bucket-name \
  --key document.pdf \
  --version-id $VERSION_ID \
  document-v1.pdf

# すべてのバージョンをダウンロード
BUCKET="my-bucket"
KEY="document.pdf"

aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix $KEY \
  --query "Versions[].[VersionId,LastModified]" \
  --output text | \
while read version_id last_modified; do
  filename="document-${version_id}.pdf"
  echo "ダウンロード: $filename ($last_modified)"
  
  aws s3api get-object \
    --bucket $BUCKET \
    --key $KEY \
    --version-id $version_id \
    $filename
done
```

### バージョンの削除

```bash
# 特定のバージョンを完全に削除
aws s3api delete-object \
  --bucket my-bucket-name \
  --key document.pdf \
  --version-id abc123...

# 最新バージョンを削除（削除マーカーを作成）
aws s3 rm s3://my-bucket-name/document.pdf

# この操作は削除マーカーを作成し、オブジェクトは物理的に削除されない

# 削除マーカーを削除（オブジェクトを復元）
DELETE_MARKER_ID="xyz789..."
aws s3api delete-object \
  --bucket my-bucket-name \
  --key document.pdf \
  --version-id $DELETE_MARKER_ID

# すべてのバージョンを削除（完全削除）
BUCKET="my-bucket"
KEY="document.pdf"

aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix $KEY \
  --query "Versions[].[VersionId]" \
  --output text | \
while read version_id; do
  echo "削除中: $version_id"
  aws s3api delete-object \
    --bucket $BUCKET \
    --key $KEY \
    --version-id $version_id
done
```

### バージョニングのライフサイクル管理

```bash
# 旧バージョンを自動的に管理
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "version-management",
      "Status": "Enabled",
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "NoncurrentDays": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 365,
        "NewerNoncurrentVersions": 3
      }
    }]
  }'

# ライフサイクルルールの詳細:
# - 30日後に STANDARD_IA に移行
# - 90日後に GLACIER に移行
# - 365日後に削除（最新3バージョンは保持）
```

### 実用的なバージョン管理スクリプト

```bash
#!/bin/bash
# オブジェクトのバージョン履歴を表示

BUCKET="${1}"
KEY="${2}"

if [ -z "$BUCKET" ] || [ -z "$KEY" ]; then
  echo "使用方法: $0 <bucket-name> <object-key>"
  exit 1
fi

echo "=== バージョン履歴: s3://$BUCKET/$KEY ==="
echo ""

# バージョン一覧を取得
aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix $KEY \
  --query "Versions[].[VersionId,LastModified,Size,IsLatest]" \
  --output text | \
while read version_id last_modified size is_latest; do
  # サイズを人間が読みやすい形式に変換
  if [ $size -lt 1024 ]; then
    size_human="${size}B"
  elif [ $size -lt 1048576 ]; then
    size_human="$(( size / 1024 ))KB"
  else
    size_human="$(( size / 1048576 ))MB"
  fi
  
  # 最新バージョンにマーク
  latest_mark=""
  [ "$is_latest" = "True" ] && latest_mark=" [最新]"
  
  echo "バージョンID: $version_id$latest_mark"
  echo "  更新日時: $last_modified"
  echo "  サイズ: $size_human"
  echo ""
done

# 削除マーカーを表示
delete_markers=$(aws s3api list-object-versions \
  --bucket $BUCKET \
  --prefix $KEY \
  --query "DeleteMarkers[].[VersionId,LastModified]" \
  --output text)

if [ -n "$delete_markers" ]; then
  echo "=== 削除マーカー ==="
  echo "$delete_markers" | \
  while read version_id last_modified; do
    echo "削除マーカーID: $version_id"
    echo "  削除日時: $last_modified"
    echo ""
  done
fi
```

### バージョニングのベストプラクティス

**有効化を推奨するケース:**
- 重要なビジネスデータ
- コンプライアンス要件があるデータ
- 複数ユーザーが編集するファイル
- バックアップ用バケット

**コスト管理:**
```bash
# 古いバージョンのストレージコストを削減
# 1. ライフサイクルポリシーで古いバージョンを自動削除
# 2. 不要なバージョンを定期的に手動削除
# 3. 重要なファイルのみバージョニングを有効化

# バージョン数が多いオブジェクトを特定
BUCKET="my-bucket"

aws s3api list-objects-v2 --bucket $BUCKET --query "Contents[].[Key]" --output text | \
while read key; do
  version_count=$(aws s3api list-object-versions \
    --bucket $BUCKET \
    --prefix "$key" \
    --query "length(Versions)" 2>/dev/null)
  
  if [ "$version_count" -gt 10 ]; then
    echo "$key: $version_count バージョン"
  fi
done | sort -t':' -k2 -rn | head -20
```

**セキュリティ:**
- 本番環境では MFA削除を有効化
- バージョン削除の権限を制限
- CloudTrailでバージョン操作を監査
- バケットポリシーでバージョン削除を制限

```bash
# バージョン削除を禁止するバケットポリシー
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "DenyDeleteObjectVersion",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:DeleteObjectVersion",
      "Resource": "arn:aws:s3:::my-bucket-name/*",
      "Condition": {
        "StringNotLike": {
          "aws:userid": ["AIDAI23EXAMPLEID:*"]
        }
      }
    }]
  }'
```

**運用上の注意点:**
- バージョニングを有効化する前にデータ保持ポリシーを決定
- ライフサイクルルールと組み合わせて自動管理
- 定期的にバージョン数とストレージ使用量を監視
- テスト環境で動作を確認してから本番環境に適用

---

## バケットの暗号化

S3のサーバー側暗号化により、保存時のデータを自動的に暗号化できます。暗号化はバケットレベルでデフォルト設定することで、すべての新規オブジェクトが自動的に暗号化されます。

### 暗号化方式の概要

**SSE-S3 (Amazon S3 マネージド型キー):**
- S3が管理する暗号化キーを使用
- AES-256暗号化
- 追加料金なし
- 最もシンプルな設定

**SSE-KMS (AWS KMS マネージド型キー):**
- AWS KMS（Key Management Service）を使用
- キーの使用状況を監査可能
- キーのローテーション管理
- リクエストごとに料金が発生

**SSE-C (カスタマー提供キー):**
- お客様が管理する暗号化キーを使用
- リクエストごとにキーを提供
- AWS側でキーは保存されない

### デフォルト暗号化の設定（SSE-S3）

```bash
# SSE-S3（AES256）で暗号化
aws s3api put-bucket-encryption \
  --bucket my-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# 実行結果: 出力なし（成功時）

# BucketKeyEnabled の効果:
# - S3 バケットキーを使用してKMSリクエスト数を削減
# - コスト削減（KMS使用時に有効）
# - SSE-S3でも設定可能だが効果はない
```

### KMSキーを使用した暗号化（SSE-KMS）

```bash
# デフォルトのKMSキー（aws/s3）を使用
aws s3api put-bucket-encryption \
  --bucket my-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      },
      "BucketKeyEnabled": true
    }]
  }'

# カスタムKMSキーを使用
KMS_KEY_ID="arn:aws:kms:ap-northeast-1:123456789012:key/12345678-1234-1234-1234-123456789012"

aws s3api put-bucket-encryption \
  --bucket my-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'$KMS_KEY_ID'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# キーエイリアスでも指定可能
aws s3api put-bucket-encryption \
  --bucket my-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/my-custom-key"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

### 暗号化設定の確認

```bash
# 暗号化設定を確認
aws s3api get-bucket-encryption --bucket my-bucket-name

# 出力例（SSE-S3）:
# {
#     "ServerSideEncryptionConfiguration": {
#         "Rules": [
#             {
#                 "ApplyServerSideEncryptionByDefault": {
#                     "SSEAlgorithm": "AES256"
#                 },
#                 "BucketKeyEnabled": true
#             }
#         ]
#     }
# }

# 出力例（SSE-KMS）:
# {
#     "ServerSideEncryptionConfiguration": {
#         "Rules": [
#             {
#                 "ApplyServerSideEncryptionByDefault": {
#                     "SSEAlgorithm": "aws:kms",
#                     "KMSMasterKeyID": "arn:aws:kms:ap-northeast-1:123456789012:key/..."
#                 },
#                 "BucketKeyEnabled": true
#             }
#         ]
#     }
# }

# 暗号化方式のみを取得
aws s3api get-bucket-encryption \
  --bucket my-bucket-name \
  --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" \
  --output text

# 暗号化が設定されていない場合:
# An error occurred (ServerSideEncryptionConfigurationNotFoundError)
```

### すべてのバケットの暗号化状態を確認

```bash
# すべてのバケットの暗号化状態を一覧表示
echo "=== バケットの暗号化状態 ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  encryption=$(aws s3api get-bucket-encryption \
    --bucket $bucket \
    --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" \
    --output text 2>/dev/null)
  
  if [ -z "$encryption" ]; then
    echo "$bucket: 未設定"
  else
    # KMSキーIDも表示（SSE-KMSの場合）
    if [ "$encryption" = "aws:kms" ]; then
      kms_key=$(aws s3api get-bucket-encryption \
        --bucket $bucket \
        --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID" \
        --output text 2>/dev/null)
      echo "$bucket: $encryption (Key: ${kms_key:-デフォルト})"
    else
      echo "$bucket: $encryption"
    fi
  fi
done

# 暗号化されていないバケットのみ表示
echo ""
echo "=== 暗号化未設定のバケット ==="
for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  if ! aws s3api get-bucket-encryption --bucket $bucket >/dev/null 2>&1; then
    echo "- $bucket"
  fi
done
```

### 暗号化設定の削除

```bash
# 暗号化設定を削除
aws s3api delete-bucket-encryption --bucket my-bucket-name

# 実行結果: 出力なし（成功時）

# 注意: デフォルト暗号化を削除しても、既存の暗号化されたオブジェクトは
#       暗号化されたまま。新規オブジェクトのみ暗号化されなくなる
```

### オブジェクトの暗号化状態を確認

```bash
# 特定のオブジェクトの暗号化状態を確認
aws s3api head-object \
  --bucket my-bucket-name \
  --key document.pdf \
  --query "{Encryption: ServerSideEncryption, KMSKeyId: SSEKMSKeyId}"

# 出力例:
# {
#     "Encryption": "aws:kms",
#     "KMSKeyId": "arn:aws:kms:ap-northeast-1:123456789012:key/..."
# }

# バケット内のすべてのオブジェクトの暗号化状態を確認
BUCKET="my-bucket"

aws s3api list-objects-v2 --bucket $BUCKET --query "Contents[].[Key]" --output text | \
while read key; do
  encryption=$(aws s3api head-object \
    --bucket $BUCKET \
    --key "$key" \
    --query "ServerSideEncryption" \
    --output text 2>/dev/null)
  
  echo "$key: ${encryption:-なし}"
done
```

### アップロード時に暗号化を指定

```bash
# SSE-S3で暗号化してアップロード
aws s3 cp document.pdf s3://my-bucket-name/ \
  --server-side-encryption AES256

# SSE-KMSで暗号化してアップロード（デフォルトキー）
aws s3 cp document.pdf s3://my-bucket-name/ \
  --server-side-encryption aws:kms

# SSE-KMSで暗号化してアップロード（カスタムキー）
aws s3 cp document.pdf s3://my-bucket-name/ \
  --server-side-encryption aws:kms \
  --ssekms-key-id arn:aws:kms:ap-northeast-1:123456789012:key/12345678...

# SSE-Cで暗号化してアップロード（カスタマー提供キー）
aws s3api put-object \
  --bucket my-bucket-name \
  --key document.pdf \
  --body document.pdf \
  --sse-customer-algorithm AES256 \
  --sse-customer-key fileb://encryption-key.bin
```

### 暗号化強制ポリシー

```bash
# HTTPSと暗号化を強制するバケットポリシー
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyUnencryptedObjectUploads",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::my-bucket-name/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption": ["AES256", "aws:kms"]
          }
        }
      },
      {
        "Sid": "DenyInsecureTransport",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::my-bucket-name",
          "arn:aws:s3:::my-bucket-name/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  }'

# 特定のKMSキーのみを許可するポリシー
KMS_KEY_ARN="arn:aws:kms:ap-northeast-1:123456789012:key/12345678..."

aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "RequireSpecificKMSKey",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-bucket-name/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption-aws-kms-key-id": "'$KMS_KEY_ARN'"
        }
      }
    }]
  }'
```

### カスタムKMSキーの作成と使用

```bash
# S3用のKMSキーを作成
KEY_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow S3 to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    }
  ]
}'

# KMSキーを作成
KEY_ID=$(aws kms create-key \
  --description "S3 encryption key for my-bucket" \
  --policy "$KEY_POLICY" \
  --query "KeyMetadata.KeyId" \
  --output text)

echo "作成したKMSキーID: $KEY_ID"

# キーエイリアスを作成
aws kms create-alias \
  --alias-name alias/s3-my-bucket-key \
  --target-key-id $KEY_ID

# S3バケットでKMSキーを使用
aws s3api put-bucket-encryption \
  --bucket my-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'$KEY_ID'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# KMSキーの使用状況を確認
aws kms get-key-rotation-status --key-id $KEY_ID

# キーのローテーションを有効化（推奨）
aws kms enable-key-rotation --key-id $KEY_ID
```

### 既存オブジェクトの暗号化

デフォルト暗号化を設定しても、既存のオブジェクトは暗号化されません。既存オブジェクトを暗号化するには再アップロードが必要です。

```bash
#!/bin/bash
# 既存オブジェクトを暗号化するスクリプト

BUCKET="my-bucket-name"
ENCRYPTION="aws:kms"  # または "AES256"

echo "バケット内のオブジェクトを暗号化中..."

aws s3api list-objects-v2 --bucket $BUCKET --query "Contents[].[Key]" --output text | \
while read key; do
  echo "処理中: $key"
  
  # オブジェクトをコピーして暗号化（メタデータ保持）
  aws s3 cp \
    s3://$BUCKET/"$key" \
    s3://$BUCKET/"$key" \
    --server-side-encryption $ENCRYPTION \
    --metadata-directive COPY
done

echo "完了"

# 大量のオブジェクトがある場合は並列処理
# parallel -j 10を使用（GNU parallelがインストール済みの場合）
aws s3api list-objects-v2 --bucket $BUCKET --query "Contents[].[Key]" --output text | \
parallel -j 10 "aws s3 cp s3://$BUCKET/{} s3://$BUCKET/{} --server-side-encryption $ENCRYPTION --metadata-directive COPY"
```

### 暗号化のコスト比較

```bash
# コスト試算スクリプト
BUCKET="my-bucket"

# オブジェクト数を取得
object_count=$(aws s3api list-objects-v2 \
  --bucket $BUCKET \
  --query "length(Contents)" 2>/dev/null)

echo "=== 暗号化コスト試算 ==="
echo "バケット: $BUCKET"
echo "オブジェクト数: $object_count"
echo ""
echo "SSE-S3 (AES256):"
echo "  - 追加料金: なし"
echo ""
echo "SSE-KMS:"
echo "  - KMSリクエスト料金: 約 $0.03 / 10,000 リクエスト"
echo "  - 月間推定コスト（BucketKey無効）: \$$(echo "scale=2; $object_count * 0.03 / 10000" | bc)"
echo "  - 月間推定コスト（BucketKey有効）: 大幅に削減"
echo ""
echo "推奨: BucketKeyEnabled を true に設定してコスト削減"
```

### 暗号化のベストプラクティス

**暗号化方式の選択:**
- **SSE-S3**: 一般的なユースケース、追加料金なし
- **SSE-KMS**: 監査が必要、キーの細かい管理が必要
- **SSE-C**: 完全なキー管理を自社で行いたい場合

**推奨設定:**
```bash
# セキュアなバケットのセットアップ
BUCKET_NAME="secure-data-bucket"
REGION="ap-northeast-1"

# 1. バケット作成
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# 2. パブリックアクセスブロック
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 3. デフォルト暗号化（SSE-S3）
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# 4. バージョニング有効化
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 5. HTTPSと暗号化を強制
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyUnencryptedObjectUploads",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption": ["AES256", "aws:kms"]
          }
        }
      },
      {
        "Sid": "DenyInsecureTransport",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::'$BUCKET_NAME'",
          "arn:aws:s3:::'$BUCKET_NAME'/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  }'

echo "セキュアなバケット $BUCKET_NAME をセットアップしました"
```

**監査とコンプライアンス:**
- すべてのバケットでデフォルト暗号化を有効化
- KMS使用時はCloudTrailでキー使用状況を監査
- 定期的に暗号化状態を確認
- 暗号化されていないオブジェクトのアップロードを禁止

**Tips:**
- BucketKeyEnabled を true にすると、KMSのコストを大幅に削減（最大99%）
- SSE-S3 は無料、SSE-KMS はリクエストごとに料金が発生
- デフォルト暗号化を設定しても、既存オブジェクトは暗号化されない
- 2023年1月以降、新規バケットはデフォルトでSSE-S3が有効

---

## ライフサイクルルール

### 基本的なライフサイクルルールの設定

```bash
# 30日後にIA、90日後にGLACIERに移行
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "archive-old-objects",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }]
  }'
```

### 有効期限による自動削除

```bash
# 365日後に自動削除
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "delete-old-logs",
      "Status": "Enabled",
      "Prefix": "logs/",
      "Expiration": {
        "Days": 365
      }
    }]
  }'
```

### 不完全なマルチパートアップロードの削除

```bash
# 7日後に不完全なアップロードを削除
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "delete-incomplete-uploads",
      "Status": "Enabled",
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }]
  }'
```

### 複数ルールの組み合わせ

```bash
# 複雑なライフサイクルポリシー
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [
      {
        "Id": "logs-lifecycle",
        "Status": "Enabled",
        "Filter": {
          "Prefix": "logs/"
        },
        "Transitions": [
          {
            "Days": 30,
            "StorageClass": "STANDARD_IA"
          },
          {
            "Days": 90,
            "StorageClass": "GLACIER"
          }
        ],
        "Expiration": {
          "Days": 365
        }
      },
      {
        "Id": "temp-files-cleanup",
        "Status": "Enabled",
        "Filter": {
          "Prefix": "tmp/"
        },
        "Expiration": {
          "Days": 7
        }
      },
      {
        "Id": "abort-incomplete-uploads",
        "Status": "Enabled",
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 7
        }
      }
    ]
  }'
```

### バージョニング有効時のライフサイクル

```bash
# 旧バージョンの管理
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "version-management",
      "Status": "Enabled",
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "NoncurrentDays": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 365
      }
    }]
  }'
```

### ライフサイクル設定の確認と削除

```bash
# ライフサイクル設定を確認
aws s3api get-bucket-lifecycle-configuration --bucket my-bucket-name

# ライフサイクル設定を削除
aws s3api delete-bucket-lifecycle --bucket my-bucket-name
```

---

## バケットタグ

### タグの設定

```bash
# タグを設定
aws s3api put-bucket-tagging \
  --bucket my-bucket-name \
  --tagging 'TagSet=[
    {Key=Environment,Value=Production},
    {Key=Project,Value=WebApp},
    {Key=CostCenter,Value=Engineering}
  ]'

# 単一タグの設定
aws s3api put-bucket-tagging \
  --bucket my-bucket-name \
  --tagging 'TagSet=[{Key=Environment,Value=Development}]'
```

### タグの確認

```bash
# タグを確認
aws s3api get-bucket-tagging --bucket my-bucket-name

# 出力例:
# {
#     "TagSet": [
#         {
#             "Key": "Environment",
#             "Value": "Production"
#         },
#         {
#             "Key": "Project",
#             "Value": "WebApp"
#         }
#     ]
# }

# 特定のタグの値を取得
aws s3api get-bucket-tagging \
  --bucket my-bucket-name \
  --query "TagSet[?Key=='Environment'].Value" \
  --output text
```

### タグの削除

```bash
# すべてのタグを削除
aws s3api delete-bucket-tagging --bucket my-bucket-name
```

### すべてのバケットのタグを確認

```bash
# すべてのバケットのタグを一覧表示
for bucket in $(aws s3 ls | awk '{print $3}'); do
  echo "Bucket: $bucket"
  aws s3api get-bucket-tagging --bucket $bucket 2>/dev/null || echo "  No tags"
  echo ""
done
```

**Tips:**
- タグはコスト配分レポートで使用できます
- 最大50個のタグを設定可能
- タグキーと値は大文字小文字を区別します

---

## バケットポリシー

### 基本的なバケットポリシーの設定

```bash
# パブリック読み取りを許可
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket-name/*"
    }]
  }'

# ファイルから読み込んで設定
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy file://bucket-policy.json
```

### 特定のIPアドレスからのアクセス制限

```bash
# 特定のIPからのみアクセスを許可
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "IPRestriction",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-bucket-name",
        "arn:aws:s3:::my-bucket-name/*"
      ],
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": [
            "203.0.113.0/24",
            "198.51.100.0/24"
          ]
        }
      }
    }]
  }'
```

### VPCエンドポイントからのアクセス制限

```bash
# 特定のVPCエンドポイントからのみアクセスを許可
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "VPCEndpointAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-bucket-name",
        "arn:aws:s3:::my-bucket-name/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:SourceVpce": "vpce-1234567"
        }
      }
    }]
  }'
```

### SSL/TLSの強制

```bash
# HTTPSのみを許可
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "ForceSSL",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-bucket-name",
        "arn:aws:s3:::my-bucket-name/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }]
  }'
```

### クロスアカウントアクセス

```bash
# 別のAWSアカウントからのアクセスを許可
aws s3api put-bucket-policy \
  --bucket my-bucket-name \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "CrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket-name/*"
    }]
  }'
```

### バケットポリシーの確認と削除

```bash
# バケットポリシーを確認
aws s3api get-bucket-policy --bucket my-bucket-name

# 整形して表示
aws s3api get-bucket-policy \
  --bucket my-bucket-name \
  --query Policy \
  --output text | jq .

# バケットポリシーを削除
aws s3api delete-bucket-policy --bucket my-bucket-name
```

### パブリックアクセスブロック設定

```bash
# すべてのパブリックアクセスをブロック
aws s3api put-public-access-block \
  --bucket my-bucket-name \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# パブリックアクセスブロック設定を確認
aws s3api get-public-access-block --bucket my-bucket-name

# パブリックアクセスブロック設定を削除
aws s3api delete-public-access-block --bucket my-bucket-name
```

---

## CORS設定

### 基本的なCORS設定

```bash
# シンプルなCORS設定
aws s3api put-bucket-cors \
  --bucket my-bucket-name \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["https://example.com"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }]
  }'
```

### 複数オリジンとメソッドの設定

```bash
# 複雑なCORS設定
aws s3api put-bucket-cors \
  --bucket my-bucket-name \
  --cors-configuration '{
    "CORSRules": [
      {
        "AllowedOrigins": ["https://example.com", "https://www.example.com"],
        "AllowedMethods": ["GET", "HEAD", "PUT", "POST", "DELETE"],
        "AllowedHeaders": ["*"],
        "ExposeHeaders": ["ETag", "x-amz-server-side-encryption"],
        "MaxAgeSeconds": 3600
      },
      {
        "AllowedOrigins": ["https://api.example.com"],
        "AllowedMethods": ["GET"],
        "AllowedHeaders": ["Authorization"],
        "MaxAgeSeconds": 3000
      }
    ]
  }'
```

### ワイルドカードを使用したCORS設定

```bash
# すべてのオリジンを許可（開発環境用）
aws s3api put-bucket-cors \
  --bucket my-dev-bucket \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "HEAD", "PUT", "POST"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }]
  }'
```

### CORS設定の確認と削除

```bash
# CORS設定を確認
aws s3api get-bucket-cors --bucket my-bucket-name

# CORS設定を削除
aws s3api delete-bucket-cors --bucket my-bucket-name
```

**Tips:**
- MaxAgeSeconds はプリフライトリクエストのキャッシュ時間です
- ExposeHeaders を設定すると、ブラウザがレスポンスヘッダーにアクセスできます
- 本番環境では特定のオリジンのみを許可することを推奨します

---

## ウェブサイト設定

### 静的ウェブサイトホスティングの有効化

```bash
# 基本的なウェブサイト設定
aws s3api put-bucket-website \
  --bucket my-website-bucket \
  --website-configuration '{
    "IndexDocument": {
      "Suffix": "index.html"
    },
    "ErrorDocument": {
      "Key": "error.html"
    }
  }'
```

### リダイレクトルールの設定

```bash
# リダイレクトルール付きウェブサイト設定
aws s3api put-bucket-website \
  --bucket my-website-bucket \
  --website-configuration '{
    "IndexDocument": {
      "Suffix": "index.html"
    },
    "ErrorDocument": {
      "Key": "error.html"
    },
    "RoutingRules": [
      {
        "Condition": {
          "KeyPrefixEquals": "docs/"
        },
        "Redirect": {
          "ReplaceKeyPrefixWith": "documentation/"
        }
      },
      {
        "Condition": {
          "HttpErrorCodeReturnedEquals": "404"
        },
        "Redirect": {
          "HostName": "example.com",
          "Protocol": "https"
        }
      }
    ]
  }'
```

### 別のホストへのリダイレクト

```bash
# すべてのリクエストを別のホストにリダイレクト
aws s3api put-bucket-website \
  --bucket my-old-website \
  --website-configuration '{
    "RedirectAllRequestsTo": {
      "HostName": "new-website.example.com",
      "Protocol": "https"
    }
  }'
```

### ウェブサイト設定の確認と削除

```bash
# ウェブサイト設定を確認
aws s3api get-bucket-website --bucket my-website-bucket

# ウェブサイトエンドポイントURLを取得
BUCKET_NAME="my-website-bucket"
REGION=$(aws s3api get-bucket-location --bucket $BUCKET_NAME --query LocationConstraint --output text)
if [ "$REGION" = "None" ]; then
  REGION="us-east-1"
fi
echo "Website URL: http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"

# ウェブサイト設定を削除
aws s3api delete-bucket-website --bucket my-website-bucket
```

**Tips:**
- ウェブサイトエンドポイント経由のアクセスにはパブリック読み取り権限が必要です
- HTTPSは直接サポートされていないため、CloudFrontの使用を推奨します
- カスタムドメインを使用する場合はRoute 53でCNAMEレコードを設定します

---

## ログ設定

### サーバーアクセスログの有効化

```bash
# ログを別のバケットに保存
aws s3api put-bucket-logging \
  --bucket my-bucket-name \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "my-logs-bucket",
      "TargetPrefix": "s3-access-logs/"
    }
  }'

# ターゲットバケットに対する権限付与が必要
aws s3api put-bucket-acl \
  --bucket my-logs-bucket \
  --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery \
  --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery
```

### ログ設定の完全な例

```bash
# ログバケットの作成と設定
LOG_BUCKET="my-logs-bucket"
SOURCE_BUCKET="my-source-bucket"

# ログバケットを作成
aws s3 mb s3://$LOG_BUCKET

# ログバケットにACLを設定
aws s3api put-bucket-acl \
  --bucket $LOG_BUCKET \
  --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery \
  --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery

# ソースバケットにログ設定を適用
aws s3api put-bucket-logging \
  --bucket $SOURCE_BUCKET \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "'$LOG_BUCKET'",
      "TargetPrefix": "logs/'$SOURCE_BUCKET'/"
    }
  }'
```

### ログ設定の確認と削除

```bash
# ログ設定を確認
aws s3api get-bucket-logging --bucket my-bucket-name

# 出力例:
# {
#     "LoggingEnabled": {
#         "TargetBucket": "my-logs-bucket",
#         "TargetPrefix": "s3-access-logs/"
#     }
# }

# ログ設定を削除（ログを無効化）
aws s3api put-bucket-logging \
  --bucket my-bucket-name \
  --bucket-logging-status '{}'
```

### ログのライフサイクル管理

```bash
# ログを90日後に削除
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-logs-bucket \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "delete-old-logs",
      "Status": "Enabled",
      "Prefix": "s3-access-logs/",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ],
      "Expiration": {
        "Days": 90
      }
    }]
  }'
```

**Tips:**
- ログは数時間遅れて配信されます（ベストエフォート）
- ログファイルは自動的に圧縮されません
- CloudTrailを使用すると、より詳細なAPI呼び出しログを取得できます
- ログバケットには適切なライフサイクルポリシーを設定することを推奨します

---

## 実践例：バケットの完全なセットアップ

```bash
#!/bin/bash

# 変数設定
BUCKET_NAME="my-production-bucket"
REGION="ap-northeast-1"
LOG_BUCKET="${BUCKET_NAME}-logs"

# 1. バケット作成
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# 2. パブリックアクセスブロック
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 3. バージョニング有効化
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 4. 暗号化設定
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# 5. タグ設定
aws s3api put-bucket-tagging \
  --bucket $BUCKET_NAME \
  --tagging 'TagSet=[
    {Key=Environment,Value=Production},
    {Key=ManagedBy,Value=Terraform}
  ]'

# 6. ライフサイクルポリシー
aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET_NAME \
  --lifecycle-configuration '{
    "Rules": [
      {
        "Id": "archive-old-versions",
        "Status": "Enabled",
        "NoncurrentVersionTransitions": [{
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        }],
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 90
        }
      },
      {
        "Id": "cleanup-incomplete-uploads",
        "Status": "Enabled",
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 7
        }
      }
    ]
  }'

# 7. ログバケット作成と設定
aws s3 mb s3://$LOG_BUCKET --region $REGION
aws s3api put-bucket-acl \
  --bucket $LOG_BUCKET \
  --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery \
  --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery

# 8. ログ有効化
aws s3api put-bucket-logging \
  --bucket $BUCKET_NAME \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "'$LOG_BUCKET'",
      "TargetPrefix": "access-logs/"
    }
  }'

echo "バケット $BUCKET_NAME のセットアップが完了しました"
```

---

## ベストプラクティス

1. **命名規則**
   - DNS準拠の名前を使用
   - 環境ごとにプレフィックスを付ける（prod-、dev-）
   - 用途がわかる名前にする

2. **セキュリティ**
   - デフォルトでパブリックアクセスをブロック
   - バージョニングを有効化
   - 暗号化を必ず設定
   - MFA削除を本番環境で検討

3. **コスト最適化**
   - ライフサイクルポリシーで古いデータをアーカイブ
   - 不完全なマルチパートアップロードを自動削除
   - 不要なバージョンを定期的に削除

4. **運用**
   - タグでリソース管理
   - ログを有効化して監査証跡を保持
   - CloudTrailでAPI操作を記録

5. **パフォーマンス**
   - Transfer Accelerationを検討（グローバルアクセス）
   - 適切なストレージクラスを選択
   - CloudFrontとの統合を検討
