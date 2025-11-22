# S3 オブジェクト操作

S3オブジェクトの基本的な操作（アップロード、ダウンロード、コピー、移動、削除）とメタデータ管理、事前署名付きURLの生成方法について説明します。

## 目次

- [アップロード操作](#アップロード操作)
- [ダウンロード操作](#ダウンロード操作)
- [バケット間コピー](#バケット間コピー)
- [移動操作](#移動操作)
- [削除操作](#削除操作)
- [フィルタを使用したリスト表示](#フィルタを使用したリスト表示)
- [メタデータ操作](#メタデータ操作)
- [事前署名付きURL](#事前署名付きurl)
- [サーバーサイド暗号化](#サーバーサイド暗号化)
- [実践的なユースケース](#実践的なユースケース)

---

## アップロード操作

### cp コマンドでアップロード

高レベルコマンドで、ディレクトリの再帰的アップロードやワイルドカードをサポートします。

```bash
# 単一ファイルのアップロード
aws s3 cp myfile.txt s3://my-bucket/

# 特定のパスにアップロード
aws s3 cp myfile.txt s3://my-bucket/folder/newname.txt

# ディレクトリを再帰的にアップロード
aws s3 cp my-folder/ s3://my-bucket/my-folder/ --recursive

# 特定の拡張子のみアップロード
aws s3 cp my-folder/ s3://my-bucket/my-folder/ --recursive --exclude "*" --include "*.jpg"

# メタデータを指定してアップロード
aws s3 cp myfile.txt s3://my-bucket/ \
  --metadata "key1=value1,key2=value2"

# Content-Typeを指定
aws s3 cp index.html s3://my-bucket/ \
  --content-type "text/html; charset=utf-8"

# キャッシュコントロールを設定
aws s3 cp image.jpg s3://my-bucket/ \
  --cache-control "max-age=3600"

# パブリック読み取りACLを設定
aws s3 cp myfile.txt s3://my-bucket/ \
  --acl public-read

# ストレージクラスを指定
aws s3 cp archive.zip s3://my-bucket/ \
  --storage-class GLACIER

# 暗号化を有効化
aws s3 cp sensitive.txt s3://my-bucket/ \
  --server-side-encryption AES256
```

**主なオプション:**

- `--recursive`: ディレクトリを再帰的に処理
- `--exclude`: 除外パターン（複数指定可）
- `--include`: 含めるパターン（excludeの後に指定）
- `--metadata`: カスタムメタデータ（key=value形式）
- `--content-type`: MIMEタイプ
- `--cache-control`: キャッシュ制御ヘッダー
- `--content-disposition`: ダウンロード時のファイル名指定
- `--content-encoding`: エンコーディング（gzipなど）
- `--content-language`: コンテンツの言語
- `--acl`: アクセスコントロールリスト
- `--storage-class`: ストレージクラス（STANDARD, GLACIER, INTELLIGENT_TIERING等）
- `--dryrun`: 実行内容を確認（実際には実行しない）

### put-object コマンドでアップロード

低レベルAPIコマンドで、より詳細な制御が可能です。

```bash
# 基本的なアップロード
aws s3api put-object \
  --bucket my-bucket \
  --key myfile.txt \
  --body myfile.txt

# メタデータとタグを指定
aws s3api put-object \
  --bucket my-bucket \
  --key data.json \
  --body data.json \
  --metadata "environment=production,version=1.0" \
  --tagging "Project=WebApp&Team=DevOps"

# カスタムHTTPヘッダーを設定
aws s3api put-object \
  --bucket my-bucket \
  --key index.html \
  --body index.html \
  --content-type "text/html" \
  --content-language "ja" \
  --cache-control "max-age=86400" \
  --content-disposition "inline"

# SSE-S3暗号化
aws s3api put-object \
  --bucket my-bucket \
  --key secure.txt \
  --body secure.txt \
  --server-side-encryption AES256

# SSE-KMS暗号化（カスタムキー）
aws s3api put-object \
  --bucket my-bucket \
  --key confidential.pdf \
  --body confidential.pdf \
  --server-side-encryption aws:kms \
  --ssekms-key-id "arn:aws:kms:ap-northeast-1:123456789012:key/abcd1234-..."

# オブジェクトロックを設定（バージョニング有効時）
aws s3api put-object \
  --bucket my-bucket \
  --key legal-doc.pdf \
  --body legal-doc.pdf \
  --object-lock-mode COMPLIANCE \
  --object-lock-retain-until-date "2025-12-31T23:59:59Z"

# 標準入力からアップロード
echo "Hello S3" | aws s3api put-object \
  --bucket my-bucket \
  --key greeting.txt \
  --body -
```

**主なオプション:**

- `--bucket`: バケット名（必須）
- `--key`: S3オブジェクトキー（必須）
- `--body`: アップロードするファイルパス（必須）
- `--metadata`: カスタムメタデータ（JSONマップ）
- `--tagging`: タグ（URLエンコード形式）
- `--server-side-encryption`: 暗号化方式（AES256, aws:kms）
- `--ssekms-key-id`: KMS鍵のARN
- `--acl`: ACL設定
- `--grant-*`: 詳細なアクセス権限設定

---

## ダウンロード操作

### cp コマンドでダウンロード

```bash
# 単一ファイルのダウンロード
aws s3 cp s3://my-bucket/myfile.txt ./

# 別名で保存
aws s3 cp s3://my-bucket/myfile.txt ./newname.txt

# ディレクトリを再帰的にダウンロード
aws s3 cp s3://my-bucket/my-folder/ ./local-folder/ --recursive

# 特定のファイルのみダウンロード
aws s3 cp s3://my-bucket/images/ ./images/ \
  --recursive \
  --exclude "*" \
  --include "*.png" \
  --include "*.jpg"

# 特定の日付以降のファイルをダウンロード
aws s3 cp s3://my-bucket/logs/ ./logs/ \
  --recursive \
  --exclude "*" \
  --include "*2025-11*"

# 既存ファイルをスキップしない（上書き）
aws s3 cp s3://my-bucket/data/ ./data/ --recursive

# ドライラン（確認のみ）
aws s3 cp s3://my-bucket/large-folder/ ./backup/ \
  --recursive \
  --dryrun
```

### get-object コマンドでダウンロード

```bash
# 基本的なダウンロード
aws s3api get-object \
  --bucket my-bucket \
  --key myfile.txt \
  myfile.txt

# 特定のバージョンをダウンロード
aws s3api get-object \
  --bucket my-bucket \
  --key document.pdf \
  --version-id "3/L4kqtJlcpXroDTDmpUMLUo" \
  document-v1.pdf

# Range指定でダウンロード（部分取得）
aws s3api get-object \
  --bucket my-bucket \
  --key largefile.bin \
  --range bytes=0-1048576 \
  first-1mb.bin

# If-Modified-Since条件付きダウンロード
aws s3api get-object \
  --bucket my-bucket \
  --key data.json \
  --if-modified-since "2025-11-01T00:00:00Z" \
  data.json

# メタデータも取得（標準出力に表示）
aws s3api get-object \
  --bucket my-bucket \
  --key myfile.txt \
  myfile.txt \
  | jq '.'

# SSE-C（顧客提供の暗号化キー）でダウンロード
aws s3api get-object \
  --bucket my-bucket \
  --key encrypted.txt \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "base64encodedkey..." \
  --sse-customer-key-md5 "base64encodedmd5..." \
  encrypted.txt
```

**主なオプション:**

- `--bucket`: バケット名
- `--key`: オブジェクトキー
- `--version-id`: 特定バージョンの指定
- `--range`: バイト範囲の指定
- `--if-match`: ETagが一致する場合のみ取得
- `--if-none-match`: ETagが一致しない場合のみ取得
- `--if-modified-since`: 指定日時以降に変更された場合のみ取得
- `--if-unmodified-since`: 指定日時以降に変更されていない場合のみ取得

---

## バケット間コピー

### 同一リージョン内のコピー

```bash
# 単一オブジェクトのコピー
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/file.txt

# 別の名前でコピー
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/folder/newname.txt

# ディレクトリ全体をコピー
aws s3 cp s3://source-bucket/folder/ s3://dest-bucket/folder/ --recursive

# メタデータを変更してコピー
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/file.txt \
  --metadata-directive REPLACE \
  --metadata "newkey=newvalue"

# ストレージクラスを変更してコピー
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/file.txt \
  --storage-class GLACIER

# ACLを変更してコピー
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/file.txt \
  --acl public-read
```

### クロスリージョンコピー

```bash
# 異なるリージョンのバケット間でコピー
aws s3 cp s3://us-bucket/file.txt s3://asia-bucket/file.txt \
  --source-region us-east-1 \
  --region ap-northeast-1

# ディレクトリ全体をクロスリージョンコピー
aws s3 cp s3://us-bucket/data/ s3://asia-bucket/data/ \
  --recursive \
  --source-region us-east-1 \
  --region ap-northeast-1
```

### copy-object APIコマンド

```bash
# 基本的なコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key newfile.txt \
  --copy-source source-bucket/file.txt

# メタデータを保持してコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source source-bucket/file.txt \
  --metadata-directive COPY

# メタデータを置き換えてコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source source-bucket/file.txt \
  --metadata-directive REPLACE \
  --metadata "environment=production,version=2.0" \
  --content-type "application/json"

# タグをコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source source-bucket/file.txt \
  --tagging-directive COPY

# 暗号化を変更してコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source source-bucket/file.txt \
  --server-side-encryption aws:kms \
  --ssekms-key-id "arn:aws:kms:ap-northeast-1:123456789012:key/..."

# 特定バージョンをコピー
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source "source-bucket/file.txt?versionId=3/L4kqtJlcpXroDTDmpUMLUo"

# 条件付きコピー（ETag一致）
aws s3api copy-object \
  --bucket dest-bucket \
  --key file.txt \
  --copy-source source-bucket/file.txt \
  --copy-source-if-match "\"9b2cf535f27731c974343645a3985328\""
```

---

## 移動操作

### mv コマンド（移動）

`mv`コマンドはコピー後に元ファイルを削除します。

```bash
# 単一ファイルの移動
aws s3 mv myfile.txt s3://my-bucket/

# S3内でのファイル移動（リネーム）
aws s3 mv s3://my-bucket/old-name.txt s3://my-bucket/new-name.txt

# ディレクトリの移動
aws s3 mv s3://my-bucket/old-folder/ s3://my-bucket/new-folder/ --recursive

# ローカルからS3へ移動（ローカルファイルは削除される）
aws s3 mv ./temp-data/ s3://my-bucket/data/ --recursive

# S3からローカルへ移動（S3オブジェクトは削除される）
aws s3 mv s3://my-bucket/processed/ ./archive/ --recursive

# バケット間移動
aws s3 mv s3://source-bucket/file.txt s3://dest-bucket/file.txt

# 除外パターンを使用した移動
aws s3 mv s3://my-bucket/temp/ s3://my-bucket/archive/ \
  --recursive \
  --exclude "*.log"

# メタデータを変更して移動
aws s3 mv s3://my-bucket/file.txt s3://my-bucket/updated-file.txt \
  --metadata "status=archived,date=2025-11-15"
```

**注意点:**

- `mv`は内部的にコピー→削除を実行
- 大量のファイル移動は時間がかかる可能性がある
- エラー時は部分的にコピーされた状態になる可能性がある

---

## 削除操作

### rm コマンドで削除

```bash
# 単一オブジェクトの削除
aws s3 rm s3://my-bucket/myfile.txt

# ディレクトリを再帰的に削除
aws s3 rm s3://my-bucket/old-folder/ --recursive

# 特定のパターンに一致するオブジェクトのみ削除
aws s3 rm s3://my-bucket/logs/ \
  --recursive \
  --exclude "*" \
  --include "*.log" \
  --include "*.tmp"

# 古いログファイルのみ削除
aws s3 rm s3://my-bucket/logs/ \
  --recursive \
  --exclude "*" \
  --include "*2024*"

# ドライラン（削除予定のファイルを確認）
aws s3 rm s3://my-bucket/temp/ --recursive --dryrun

# バケット内の全オブジェクトを削除
aws s3 rm s3://my-bucket/ --recursive
```

### delete-object コマンドで削除

```bash
# 基本的な削除
aws s3api delete-object \
  --bucket my-bucket \
  --key myfile.txt

# 特定バージョンを削除（バージョニング有効時）
aws s3api delete-object \
  --bucket my-bucket \
  --key myfile.txt \
  --version-id "3/L4kqtJlcpXroDTDmpUMLUo"

# MFAによる削除保護を使用
aws s3api delete-object \
  --bucket my-bucket \
  --key protected.txt \
  --mfa "SERIAL 123456"

# バイパスガバナンスモード（特権削除）
aws s3api delete-object \
  --bucket my-bucket \
  --key locked.txt \
  --version-id "version123" \
  --bypass-governance-retention
```

### delete-objects コマンド（一括削除）

```bash
# JSONファイルで複数オブジェクトを削除
cat > delete.json <<EOF
{
  "Objects": [
    {"Key": "file1.txt"},
    {"Key": "file2.txt"},
    {"Key": "folder/file3.txt"}
  ],
  "Quiet": false
}
EOF

aws s3api delete-objects \
  --bucket my-bucket \
  --delete file://delete.json

# 特定バージョンを含めて削除
cat > delete-versions.json <<EOF
{
  "Objects": [
    {"Key": "file1.txt", "VersionId": "version1"},
    {"Key": "file2.txt", "VersionId": "version2"}
  ]
}
EOF

aws s3api delete-objects \
  --bucket my-bucket \
  --delete file://delete-versions.json

# リストから一括削除（スクリプト）
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --prefix "temp/" \
  --query 'Contents[].Key' \
  --output text | \
  xargs -n 1 -I {} aws s3api delete-object --bucket my-bucket --key {}
```

**一括削除の効率的な方法:**

```bash
# 1000件ずつ削除（API制限に対応）
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --prefix "logs/" \
  --query 'Contents[].{Key:Key}' \
  --output json | \
  jq '{Objects: .[0:1000], Quiet: true}' | \
  aws s3api delete-objects \
    --bucket my-bucket \
    --delete file:///dev/stdin
```

---

## フィルタを使用したリスト表示

### ls コマンドでリスト表示

```bash
# バケット内の全オブジェクトをリスト
aws s3 ls s3://my-bucket/

# 特定のプレフィックスでフィルタ
aws s3 ls s3://my-bucket/folder/

# 再帰的にリスト表示
aws s3 ls s3://my-bucket/ --recursive

# 人間が読みやすい形式で表示
aws s3 ls s3://my-bucket/ --recursive --human-readable

# ファイルサイズも表示
aws s3 ls s3://my-bucket/ --recursive --summarize

# 特定のパターンに一致するファイルのみ表示
aws s3 ls s3://my-bucket/images/ --recursive | grep "\.png$"

# 最新の10件を表示
aws s3 ls s3://my-bucket/ --recursive | tail -10

# サイズでソート
aws s3 ls s3://my-bucket/ --recursive | sort -k3 -n
```

### list-objects-v2 コマンドで詳細リスト

```bash
# 基本的なリスト表示
aws s3api list-objects-v2 --bucket my-bucket

# プレフィックスでフィルタ
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --prefix "logs/2025/11/"

# 区切り文字を使用してフォルダ構造を表示
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --prefix "data/" \
  --delimiter "/"

# 最大件数を指定
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --max-items 100

# ページネーション
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --max-keys 1000 \
  --starting-token "next-token-from-previous-response"

# 特定のフィールドのみ取得
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].{Key:Key,Size:Size,Modified:LastModified}' \
  --output table

# ファイル名のみ取得
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text

# 特定サイズ以上のファイルをフィルタ（10MB以上）
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[?Size > `10485760`].[Key,Size]' \
  --output table

# 特定日時以降に変更されたファイル
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[?LastModified >= `2025-11-01`].Key' \
  --output text

# ファイル数と合計サイズを計算
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --output json | \
  jq '{count: (.Contents | length), totalSize: ([.Contents[].Size] | add)}'

# 拡張子ごとにグループ化
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text | \
  sed 's/.*\.//' | \
  sort | uniq -c | sort -rn
```

### list-object-versions（バージョニング有効時）

```bash
# 全バージョンをリスト表示
aws s3api list-object-versions --bucket my-bucket

# 特定のオブジェクトのバージョン履歴
aws s3api list-object-versions \
  --bucket my-bucket \
  --prefix "important-file.txt"

# 削除マーカーも含めて表示
aws s3api list-object-versions \
  --bucket my-bucket \
  --query '{Objects:Versions[].{Key:Key,VersionId:VersionId,IsLatest:IsLatest,LastModified:LastModified}, DeleteMarkers:DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json

# 最新でないバージョンのみリスト
aws s3api list-object-versions \
  --bucket my-bucket \
  --query 'Versions[?IsLatest==`false`].[Key,VersionId]' \
  --output text
```

---

## メタデータ操作

### メタデータの表示

```bash
# オブジェクトのメタデータを表示
aws s3api head-object \
  --bucket my-bucket \
  --key myfile.txt

# 特定のフィールドのみ取得
aws s3api head-object \
  --bucket my-bucket \
  --key myfile.txt \
  --query '{ContentType:ContentType,Size:ContentLength,ETag:ETag,Metadata:Metadata}'

# カスタムメタデータのみ表示
aws s3api head-object \
  --bucket my-bucket \
  --key myfile.txt \
  --query 'Metadata'

# 複数ファイルのメタデータを一括取得
for key in $(aws s3api list-objects-v2 --bucket my-bucket --query 'Contents[].Key' --output text); do
  echo "=== $key ==="
  aws s3api head-object --bucket my-bucket --key "$key" --query 'Metadata'
done
```

### メタデータの更新

メタデータの更新は、オブジェクトを自分自身にコピーする必要があります。

```bash
# カスタムメタデータを追加/更新
aws s3 cp s3://my-bucket/myfile.txt s3://my-bucket/myfile.txt \
  --metadata-directive REPLACE \
  --metadata "version=2.0,environment=production,author=admin"

# Content-Typeを更新
aws s3 cp s3://my-bucket/file.json s3://my-bucket/file.json \
  --metadata-directive REPLACE \
  --content-type "application/json; charset=utf-8"

# Cache-Controlを更新
aws s3 cp s3://my-bucket/image.jpg s3://my-bucket/image.jpg \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=31536000, immutable"

# 複数のHTTPヘッダーを更新
aws s3 cp s3://my-bucket/download.pdf s3://my-bucket/download.pdf \
  --metadata-directive REPLACE \
  --content-type "application/pdf" \
  --content-disposition "attachment; filename=\"document.pdf\"" \
  --content-language "ja" \
  --cache-control "no-cache"

# copy-object APIで更新
aws s3api copy-object \
  --bucket my-bucket \
  --key myfile.txt \
  --copy-source my-bucket/myfile.txt \
  --metadata-directive REPLACE \
  --metadata "key1=value1,key2=value2" \
  --content-type "text/plain"
```

### タグの管理

```bash
# タグを追加
aws s3api put-object-tagging \
  --bucket my-bucket \
  --key myfile.txt \
  --tagging 'TagSet=[{Key=Environment,Value=Production},{Key=Team,Value=DevOps}]'

# タグを取得
aws s3api get-object-tagging \
  --bucket my-bucket \
  --key myfile.txt

# タグを削除
aws s3api delete-object-tagging \
  --bucket my-bucket \
  --key myfile.txt

# アップロード時にタグを設定
aws s3 cp myfile.txt s3://my-bucket/ \
  --tagging "Project=WebApp&CostCenter=Engineering"

# タグでフィルタリング
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text | \
  while read key; do
    tags=$(aws s3api get-object-tagging --bucket my-bucket --key "$key" --query 'TagSet[?Key==`Environment`].Value' --output text)
    if [ "$tags" = "Production" ]; then
      echo "$key"
    fi
  done
```

### ACL（アクセスコントロールリスト）の管理

```bash
# ACLを表示
aws s3api get-object-acl \
  --bucket my-bucket \
  --key myfile.txt

# ACLを設定（事前定義）
aws s3api put-object-acl \
  --bucket my-bucket \
  --key myfile.txt \
  --acl public-read

# カスタムACLを設定
aws s3api put-object-acl \
  --bucket my-bucket \
  --key myfile.txt \
  --grant-read 'uri="http://acs.amazonaws.com/groups/global/AllUsers"' \
  --grant-full-control 'emailaddress="admin@example.com"'

# ACLをJSONファイルで設定
cat > acl.json <<EOF
{
  "Owner": {
    "ID": "canonical-user-id"
  },
  "Grants": [
    {
      "Grantee": {
        "Type": "CanonicalUser",
        "ID": "canonical-user-id"
      },
      "Permission": "FULL_CONTROL"
    }
  ]
}
EOF

aws s3api put-object-acl \
  --bucket my-bucket \
  --key myfile.txt \
  --access-control-policy file://acl.json
```

---

## 事前署名付きURL

事前署名付きURLは、一時的にオブジェクトへのアクセスを許可するURLです。

### presign コマンド

```bash
# 基本的な事前署名付きURL生成（デフォルト1時間有効）
aws s3 presign s3://my-bucket/myfile.txt

# 有効期限を指定（秒単位、最大7日間=604800秒）
aws s3 presign s3://my-bucket/myfile.txt --expires-in 3600

# 24時間有効なURL
aws s3 presign s3://my-bucket/document.pdf --expires-in 86400

# 特定のリージョンを指定
aws s3 presign s3://my-bucket/myfile.txt \
  --region ap-northeast-1 \
  --expires-in 7200

# プロファイルを指定
aws s3 presign s3://my-bucket/myfile.txt \
  --profile production \
  --expires-in 1800
```

### presign コマンドの実用例

```bash
# ダウンロードリンクを生成してメールで送信
URL=$(aws s3 presign s3://my-bucket/report.pdf --expires-in 86400)
echo "Download link (valid for 24 hours): $URL" | mail -s "Report Ready" user@example.com

# 複数ファイルの署名付きURLを生成
for key in $(aws s3api list-objects-v2 --bucket my-bucket --prefix "downloads/" --query 'Contents[].Key' --output text); do
  url=$(aws s3 presign s3://my-bucket/$key --expires-in 3600)
  echo "$key: $url"
done > presigned-urls.txt

# Webページ用のHTML生成
KEY="image.jpg"
URL=$(aws s3 presign s3://my-bucket/$KEY --expires-in 3600)
echo "<img src=\"$URL\" alt=\"$KEY\">"

# cURLでダウンロード
URL=$(aws s3 presign s3://my-bucket/file.zip --expires-in 600)
curl -o file.zip "$URL"
```

### アップロード用の事前署名付きURL

`presign`コマンドはダウンロード用ですが、アップロード用のURLは`s3api`で生成します。

```bash
# PUT用の事前署名付きURL生成（boto3やSDKを使用）
# AWS CLIでは直接生成できないため、以下のようなPythonスクリプトを使用

cat > generate_upload_url.py <<'EOF'
import boto3
import sys

s3_client = boto3.client('s3')
bucket = sys.argv[1]
key = sys.argv[2]
expires = int(sys.argv[3]) if len(sys.argv) > 3 else 3600

url = s3_client.generate_presigned_url(
    'put_object',
    Params={'Bucket': bucket, 'Key': key},
    ExpiresIn=expires
)
print(url)
EOF

python3 generate_upload_url.py my-bucket upload/file.txt 3600

# 生成されたURLを使用してアップロード
# curl -X PUT --upload-file localfile.txt "presigned-url"
```

---

## サーバーサイド暗号化

S3ではオブジェクトを暗号化して保存できます。

### SSE-S3（S3管理の暗号化キー）

```bash
# アップロード時に暗号化を有効化
aws s3 cp myfile.txt s3://my-bucket/ \
  --server-side-encryption AES256

# 既存オブジェクトに暗号化を追加（コピーして置き換え）
aws s3 cp s3://my-bucket/myfile.txt s3://my-bucket/myfile.txt \
  --server-side-encryption AES256 \
  --metadata-directive REPLACE

# put-objectで暗号化
aws s3api put-object \
  --bucket my-bucket \
  --key secure.txt \
  --body secure.txt \
  --server-side-encryption AES256

# 暗号化状態を確認
aws s3api head-object \
  --bucket my-bucket \
  --key secure.txt \
  --query 'ServerSideEncryption'
```

### SSE-KMS（AWS KMS管理の暗号化キー）

```bash
# デフォルトKMSキーで暗号化
aws s3 cp myfile.txt s3://my-bucket/ \
  --server-side-encryption aws:kms

# カスタムKMSキーを指定
aws s3 cp myfile.txt s3://my-bucket/ \
  --server-side-encryption aws:kms \
  --ssekms-key-id "arn:aws:kms:ap-northeast-1:123456789012:key/12345678-1234-1234-1234-123456789012"

# KMSキーのエイリアスを使用
aws s3 cp myfile.txt s3://my-bucket/ \
  --server-side-encryption aws:kms \
  --ssekms-key-id "alias/my-key"

# KMS暗号化コンテキストを指定
aws s3api put-object \
  --bucket my-bucket \
  --key confidential.txt \
  --body confidential.txt \
  --server-side-encryption aws:kms \
  --ssekms-key-id "alias/my-key" \
  --ssekms-encryption-context "department=finance,classification=confidential"

# バケットキーを使用（コスト削減）
aws s3 cp myfile.txt s3://my-bucket/ \
  --server-side-encryption aws:kms \
  --bucket-key-enabled

# KMS暗号化の詳細を確認
aws s3api head-object \
  --bucket my-bucket \
  --key confidential.txt \
  --query '{Encryption:ServerSideEncryption,KMSKeyId:SSEKMSKeyId}'
```

### SSE-C（顧客提供の暗号化キー）

```bash
# Base64エンコードされたキーを準備
KEY=$(openssl rand -base64 32)
KEY_MD5=$(echo -n "$KEY" | base64 -d | md5 | awk '{print $1}' | xxd -r -p | base64)

# アップロード時に暗号化
aws s3api put-object \
  --bucket my-bucket \
  --key encrypted.txt \
  --body encrypted.txt \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "$KEY" \
  --sse-customer-key-md5 "$KEY_MD5"

# ダウンロード時に同じキーを指定
aws s3api get-object \
  --bucket my-bucket \
  --key encrypted.txt \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "$KEY" \
  --sse-customer-key-md5 "$KEY_MD5" \
  decrypted.txt

# コピー時の暗号化キー指定
aws s3api copy-object \
  --bucket my-bucket \
  --key encrypted-copy.txt \
  --copy-source my-bucket/encrypted.txt \
  --copy-source-sse-customer-algorithm AES256 \
  --copy-source-sse-customer-key "$KEY" \
  --copy-source-sse-customer-key-md5 "$KEY_MD5" \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "$KEY" \
  --sse-customer-key-md5 "$KEY_MD5"
```

### 暗号化の一括適用

```bash
# バケット内の全オブジェクトに暗号化を適用
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text | \
  while read key; do
    echo "Encrypting: $key"
    aws s3 cp s3://my-bucket/"$key" s3://my-bucket/"$key" \
      --server-side-encryption AES256 \
      --metadata-directive COPY
  done

# 特定のプレフィックス配下のみ暗号化
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --prefix "sensitive/" \
  --query 'Contents[].Key' \
  --output text | \
  while read key; do
    aws s3 cp s3://my-bucket/"$key" s3://my-bucket/"$key" \
      --server-side-encryption aws:kms \
      --ssekms-key-id "alias/sensitive-data-key" \
      --metadata-directive COPY
  done
```

---

## 実践的なユースケース

### 1. 静的ウェブサイトのデプロイ

```bash
# ウェブサイトファイルをアップロード
aws s3 sync ./dist/ s3://my-website-bucket/ \
  --acl public-read \
  --cache-control "max-age=86400" \
  --exclude "*.map" \
  --delete

# HTMLファイルのContent-Typeを設定
aws s3 cp ./dist/ s3://my-website-bucket/ \
  --recursive \
  --exclude "*" \
  --include "*.html" \
  --content-type "text/html; charset=utf-8" \
  --cache-control "no-cache"

# CSSとJSファイルのキャッシュを長く設定
aws s3 cp ./dist/ s3://my-website-bucket/ \
  --recursive \
  --exclude "*" \
  --include "*.css" \
  --include "*.js" \
  --content-type "text/css" \
  --cache-control "public, max-age=31536000, immutable"

# 画像ファイルの最適化設定
aws s3 cp ./dist/images/ s3://my-website-bucket/images/ \
  --recursive \
  --content-type "image/jpeg" \
  --cache-control "public, max-age=2592000"
```

### 2. バックアップと復元

```bash
# ローカルデータをS3にバックアップ
aws s3 sync /data/important/ s3://backup-bucket/$(date +%Y-%m-%d)/ \
  --storage-class GLACIER_IR \
  --exclude "*.tmp" \
  --exclude ".DS_Store"

# 差分バックアップ（変更されたファイルのみ）
aws s3 sync /data/important/ s3://backup-bucket/latest/ \
  --size-only

# 世代管理付きバックアップ
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
aws s3 sync /data/important/ s3://backup-bucket/$BACKUP_NAME/ \
  --storage-class STANDARD_IA

# バックアップから復元
aws s3 sync s3://backup-bucket/2025-11-15/ /data/restore/ \
  --request-payer requester

# 特定のファイルのみ復元
aws s3 cp s3://backup-bucket/2025-11-15/database.sql /data/restore/ \
  --recursive \
  --exclude "*" \
  --include "*.sql"
```

### 3. ログファイルの収集と管理

```bash
# ログファイルをS3にアップロード
aws s3 cp /var/log/app.log s3://log-bucket/$(date +%Y/%m/%d)/$(hostname)/app.log \
  --storage-class INTELLIGENT_TIERING

# 複数サーバーからログを収集（スクリプト）
#!/bin/bash
BUCKET="log-bucket"
DATE_PATH=$(date +%Y/%m/%d)
HOSTNAME=$(hostname)

for log in /var/log/*.log; do
  LOGNAME=$(basename "$log")
  aws s3 cp "$log" s3://$BUCKET/$DATE_PATH/$HOSTNAME/$LOGNAME
done

# 古いログを削除（30日以上前）
CUTOFF_DATE=$(date -d '30 days ago' +%Y-%m-%d)
aws s3api list-objects-v2 \
  --bucket log-bucket \
  --query "Contents[?LastModified<'$CUTOFF_DATE'].Key" \
  --output text | \
  xargs -n 1 -I {} aws s3 rm s3://log-bucket/{}

# ログをダウンロードして解析
aws s3 cp s3://log-bucket/2025/11/15/ ./logs/ \
  --recursive \
  --exclude "*" \
  --include "*.log" \
  && grep "ERROR" ./logs/*.log
```

### 4. 大容量ファイルの転送

```bash
# マルチパートアップロードの閾値を設定（デフォルト8MB）
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB

# 大容量ファイルのアップロード
aws s3 cp large-file.zip s3://my-bucket/ \
  --storage-class GLACIER_IR

# 並列アップロードの最大数を設定
aws configure set default.s3.max_concurrent_requests 20

# 帯域制限付きアップロード（サードパーティツール使用）
# rclone --bwlimit 10M copy large-file.zip s3://my-bucket/

# 再開可能なアップロード（進行状況確認）
aws s3 cp large-video.mp4 s3://my-bucket/ \
  --expected-size 10737418240

# チェックサムで整合性確認
aws s3api put-object \
  --bucket my-bucket \
  --key large-file.zip \
  --body large-file.zip \
  --checksum-algorithm SHA256 \
  --checksum-sha256 "$(shasum -a 256 large-file.zip | awk '{print $1}')"
```

### 5. データの移行

```bash
# バケット間の完全移行
aws s3 sync s3://old-bucket/ s3://new-bucket/ \
  --source-region us-east-1 \
  --region ap-northeast-1 \
  --storage-class STANDARD_IA

# メタデータを保持して移行
aws s3 sync s3://old-bucket/ s3://new-bucket/ \
  --metadata-directive COPY

# 暗号化を追加して移行
aws s3 sync s3://old-bucket/ s3://new-bucket/ \
  --server-side-encryption aws:kms \
  --ssekms-key-id "alias/new-key"

# 移行の検証
OLD_COUNT=$(aws s3 ls s3://old-bucket/ --recursive | wc -l)
NEW_COUNT=$(aws s3 ls s3://new-bucket/ --recursive | wc -l)
echo "Old bucket: $OLD_COUNT files"
echo "New bucket: $NEW_COUNT files"

# ETLパイプライン用の移行
aws s3 sync s3://raw-data-bucket/ s3://processed-data-bucket/ \
  --exclude "*" \
  --include "*.json" \
  --exclude "*/tmp/*"
```

### 6. マルチパートアップロードの手動制御

```bash
# マルチパートアップロードを開始
UPLOAD_ID=$(aws s3api create-multipart-upload \
  --bucket my-bucket \
  --key large-file.bin \
  --query 'UploadId' \
  --output text)

# パートをアップロード（例: 100MBずつ）
aws s3api upload-part \
  --bucket my-bucket \
  --key large-file.bin \
  --part-number 1 \
  --body part1.bin \
  --upload-id $UPLOAD_ID

# マルチパートアップロードを完了
cat > parts.json <<EOF
{
  "Parts": [
    {"PartNumber": 1, "ETag": "etag-from-upload-part-1"},
    {"PartNumber": 2, "ETag": "etag-from-upload-part-2"}
  ]
}
EOF

aws s3api complete-multipart-upload \
  --bucket my-bucket \
  --key large-file.bin \
  --upload-id $UPLOAD_ID \
  --multipart-upload file://parts.json

# 進行中のマルチパートアップロードをリスト
aws s3api list-multipart-uploads --bucket my-bucket

# マルチパートアップロードを中止
aws s3api abort-multipart-upload \
  --bucket my-bucket \
  --key large-file.bin \
  --upload-id $UPLOAD_ID
```

### 7. オブジェクトのバージョン管理

```bash
# バージョニングを有効化（事前にバケットで設定）
# aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled

# 最新バージョンを取得
aws s3 cp s3://my-bucket/document.txt ./

# 特定バージョンを取得
aws s3api get-object \
  --bucket my-bucket \
  --key document.txt \
  --version-id "3/L4kqtJlcpXroDTDmpUMLUo" \
  document-v1.txt

# 全バージョンをリスト
aws s3api list-object-versions \
  --bucket my-bucket \
  --prefix "document.txt"

# 古いバージョンを削除
aws s3api list-object-versions \
  --bucket my-bucket \
  --prefix "document.txt" \
  --query 'Versions[?IsLatest==`false`].[Key,VersionId]' \
  --output text | \
  while read key version; do
    aws s3api delete-object \
      --bucket my-bucket \
      --key "$key" \
      --version-id "$version"
  done

# バージョンを復元（削除マーカーを削除）
LATEST_DELETE_MARKER=$(aws s3api list-object-versions \
  --bucket my-bucket \
  --prefix "document.txt" \
  --query 'DeleteMarkers[0].VersionId' \
  --output text)

aws s3api delete-object \
  --bucket my-bucket \
  --key document.txt \
  --version-id "$LATEST_DELETE_MARKER"
```

### 8. 条件付き操作

```bash
# ETagが一致する場合のみダウンロード
ETAG="9b2cf535f27731c974343645a3985328"
aws s3api get-object \
  --bucket my-bucket \
  --key myfile.txt \
  --if-match "\"$ETAG\"" \
  myfile.txt

# 変更されている場合のみダウンロード
LAST_MODIFIED="2025-11-01T00:00:00Z"
aws s3api get-object \
  --bucket my-bucket \
  --key data.json \
  --if-modified-since "$LAST_MODIFIED" \
  data.json

# 変更されていない場合のみアップロード
CURRENT_ETAG=$(aws s3api head-object --bucket my-bucket --key myfile.txt --query 'ETag' --output text 2>/dev/null || echo "")
if [ -z "$CURRENT_ETAG" ] || [ "$CURRENT_ETAG" != "$EXPECTED_ETAG" ]; then
  aws s3 cp myfile.txt s3://my-bucket/
else
  echo "File unchanged, skipping upload"
fi
```

### 9. 一括処理スクリプト

```bash
# 特定のプレフィックス配下のファイルを一括処理
#!/bin/bash
BUCKET="my-bucket"
PREFIX="images/"

aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "$PREFIX" \
  --query 'Contents[].Key' \
  --output text | \
  while read -r key; do
    echo "Processing: $key"
    
    # 画像を圧縮してアップロード（例）
    aws s3 cp s3://$BUCKET/"$key" - | \
      convert - -quality 85 - | \
      aws s3 cp - s3://$BUCKET/"${key%.jpg}-compressed.jpg"
  done

# 並列処理で高速化
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text | \
  xargs -P 10 -I {} aws s3 cp s3://my-bucket/{} s3://backup-bucket/{}

# エラーハンドリング付き処理
process_object() {
  local key=$1
  if aws s3 cp s3://my-bucket/"$key" /tmp/"$key" 2>/dev/null; then
    echo "Success: $key"
  else
    echo "Error: $key" >> errors.log
  fi
}

export -f process_object

aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].Key' \
  --output text | \
  xargs -n 1 -P 5 -I {} bash -c 'process_object "{}"'
```

---

## まとめ

### 主要コマンドの使い分け

| 操作 | 高レベル（s3） | 低レベル（s3api） | 推奨用途 |
|------|--------------|----------------|---------|
| アップロード | `cp`, `sync` | `put-object` | 通常はcp、詳細制御はput-object |
| ダウンロード | `cp`, `sync` | `get-object` | 通常はcp、バージョン指定はget-object |
| コピー | `cp` | `copy-object` | 通常はcp、メタデータ変更はcopy-object |
| 削除 | `rm` | `delete-object` | 通常はrm、バージョン削除はdelete-object |
| リスト | `ls` | `list-objects-v2` | 簡易表示はls、フィルタはlist-objects-v2 |

### ベストプラクティス

1. **大容量ファイルの転送**: マルチパート設定を調整
2. **暗号化**: 機密データは必ずSSE-KMSを使用
3. **メタデータ**: Content-TypeとCache-Controlを適切に設定
4. **バージョニング**: 重要なデータは有効化
5. **ライフサイクル**: 古いデータは自動的にGlacierに移行
6. **タグ付け**: コスト管理とアクセス制御のために活用
7. **事前署名付きURL**: 一時的なアクセス許可に使用
8. **並列処理**: 大量のオブジェクト操作時は並列化
9. **エラーハンドリング**: スクリプトには必ずエラー処理を含める
10. **ドライラン**: 本番実行前に`--dryrun`で確認

---

## 参考リンク

- [AWS CLI S3 コマンドリファレンス](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [AWS CLI S3API コマンドリファレンス](https://docs.aws.amazon.com/cli/latest/reference/s3api/)
- [S3 ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/)
