# S3 Sync Operations

## 概要

`aws s3 sync` コマンドは、ローカルディレクトリとS3バケット間、またはS3バケット間でファイルを同期するための強力なツールです。差分のみを転送するため、効率的なデータ同期が可能です。

## 基本構文

### ローカル → S3

```bash
aws s3 sync <ローカルパス> s3://<バケット名>/<パス>
```

**例:**
```bash
# ローカルディレクトリをS3にアップロード
aws s3 sync ./website s3://my-bucket/website/

# 特定のフォルダを同期
aws s3 sync ~/Documents/backup s3://backup-bucket/documents/
```

### S3 → ローカル

```bash
aws s3 sync s3://<バケット名>/<パス> <ローカルパス>
```

**例:**
```bash
# S3からローカルにダウンロード
aws s3 sync s3://my-bucket/data ./local-data/

# バックアップをローカルに復元
aws s3 sync s3://backup-bucket/photos ~/Pictures/backup/
```

### S3 ↔ S3

```bash
aws s3 sync s3://<ソースバケット>/<パス> s3://<デスティネーションバケット>/<パス>
```

**例:**
```bash
# バケット間でデータをコピー
aws s3 sync s3://source-bucket/data s3://dest-bucket/data

# リージョン間でバックアップ
aws s3 sync s3://us-east-1-bucket/files s3://ap-northeast-1-bucket/files
```

## --delete オプション

同期先に存在するが同期元に存在しないファイルを削除します。完全な同期を実現します。

```bash
# ソースに存在しないファイルをターゲットから削除
aws s3 sync ./local-dir s3://my-bucket/dir/ --delete

# S3バケット間で削除も含めて同期
aws s3 sync s3://source-bucket/ s3://dest-bucket/ --delete
```

**注意事項:**
```bash
# バックアップを取ってから実行することを推奨
aws s3 sync s3://prod-bucket/ s3://prod-backup-$(date +%Y%m%d)/ 
aws s3 sync ./new-content s3://prod-bucket/ --delete
```

## --exclude と --include パターン

ファイルやディレクトリをフィルタリングして同期します。

### 基本的な除外

```bash
# 特定の拡張子を除外
aws s3 sync ./project s3://my-bucket/project/ \
  --exclude "*.log"

# 複数のパターンを除外
aws s3 sync ./website s3://my-bucket/site/ \
  --exclude "*.tmp" \
  --exclude "*.cache" \
  --exclude ".DS_Store"

# ディレクトリを除外
aws s3 sync ./app s3://my-bucket/app/ \
  --exclude "node_modules/*" \
  --exclude ".git/*"
```

### 包含と除外の組み合わせ

パターンは順番に評価されます。最後にマッチしたルールが適用されます。

```bash
# すべて除外してから特定のファイルのみ含める
aws s3 sync ./data s3://my-bucket/data/ \
  --exclude "*" \
  --include "*.json"

# 特定のディレクトリ以外を同期
aws s3 sync ./project s3://my-bucket/project/ \
  --exclude "test/*" \
  --exclude "docs/*"

# ログファイルは除外するが、エラーログのみ含める
aws s3 sync ./logs s3://my-bucket/logs/ \
  --exclude "*.log" \
  --include "*error*.log"
```

### 複雑なフィルタリング

```bash
# 画像ファイルのみ同期
aws s3 sync ./media s3://my-bucket/media/ \
  --exclude "*" \
  --include "*.jpg" \
  --include "*.png" \
  --include "*.gif" \
  --include "*.webp"

# 本番環境用ファイルのみ同期（開発用ファイルを除外）
aws s3 sync ./app s3://prod-bucket/app/ \
  --exclude "*.dev.js" \
  --exclude "*.test.js" \
  --exclude "*.spec.js" \
  --exclude "development/*"
```

## --size-only オプション

ファイルサイズのみで変更を判断します（タイムスタンプを無視）。

```bash
# サイズが異なるファイルのみ同期
aws s3 sync ./data s3://my-bucket/data/ --size-only

# ローカルのタイムスタンプが不正確な場合に有効
aws s3 sync s3://my-bucket/archive ./local-archive/ --size-only
```

**使用例:**
```bash
# ビルド生成物の同期（タイムスタンプは毎回変わるがサイズで判断）
aws s3 sync ./dist s3://my-bucket/dist/ --size-only
```

## --exact-timestamps オプション

タイムスタンプの完全一致を要求します（デフォルトでは秒単位の比較）。

```bash
# より厳密なタイムスタンプ比較
aws s3 sync ./important-data s3://my-bucket/data/ --exact-timestamps
```

**注意:** S3はミリ秒単位のタイムスタンプを保持しないため、このオプションの効果は限定的です。

## --dryrun オプション

実際の転送を行わず、実行される操作を表示します。

```bash
# 何が同期されるか確認
aws s3 sync ./website s3://my-bucket/site/ --dryrun

# 削除される内容を事前確認
aws s3 sync ./new-version s3://my-bucket/app/ --delete --dryrun

# 複雑なフィルタリングの動作確認
aws s3 sync ./data s3://my-bucket/data/ \
  --exclude "*" \
  --include "*.json" \
  --include "*.csv" \
  --dryrun
```

## ACL オプション

同期時にアクセス制御リスト（ACL）を設定します。

```bash
# パブリック読み取り可能に設定
aws s3 sync ./public-assets s3://my-bucket/assets/ \
  --acl public-read

# プライベート設定（デフォルト）
aws s3 sync ./private-data s3://my-bucket/data/ \
  --acl private

# 認証ユーザーのみ読み取り可能
aws s3 sync ./internal-docs s3://my-bucket/docs/ \
  --acl authenticated-read
```

**利用可能なACL:**
- `private` - 所有者のみアクセス可能（デフォルト）
- `public-read` - 誰でも読み取り可能
- `public-read-write` - 誰でも読み書き可能
- `authenticated-read` - 認証されたAWSユーザーが読み取り可能
- `aws-exec-read` - EC2インスタンスからの読み取り用
- `bucket-owner-read` - バケット所有者が読み取り可能
- `bucket-owner-full-control` - バケット所有者がフルコントロール

## ストレージクラスオプション

コスト最適化のためにストレージクラスを指定します。

```bash
# 標準ストレージ
aws s3 sync ./active-data s3://my-bucket/data/ \
  --storage-class STANDARD

# 低頻度アクセス（IA）
aws s3 sync ./archive s3://my-bucket/archive/ \
  --storage-class STANDARD_IA

# 1ゾーン低頻度アクセス
aws s3 sync ./logs s3://my-bucket/logs/ \
  --storage-class ONEZONE_IA

# Intelligent-Tiering
aws s3 sync ./mixed-access s3://my-bucket/data/ \
  --storage-class INTELLIGENT_TIERING

# Glacier（即時取得）
aws s3 sync ./cold-archive s3://my-bucket/glacier/ \
  --storage-class GLACIER_IR

# Glacier Flexible Retrieval
aws s3 sync ./long-term-backup s3://my-bucket/backup/ \
  --storage-class GLACIER

# Glacier Deep Archive
aws s3 sync ./compliance-data s3://my-bucket/compliance/ \
  --storage-class DEEP_ARCHIVE
```

**ストレージクラスの選択基準:**
```bash
# 頻繁にアクセスするデータ
aws s3 sync ./hot-data s3://my-bucket/hot/ --storage-class STANDARD

# 月次レポート（アクセス頻度低い）
aws s3 sync ./reports s3://my-bucket/reports/ --storage-class STANDARD_IA

# 7年保存義務のコンプライアンスデータ
aws s3 sync ./compliance s3://my-bucket/compliance/ --storage-class DEEP_ARCHIVE
```

## 暗号化オプション

データを暗号化して保存します。

### SSE-S3（S3管理キー）

```bash
# S3管理の暗号化キーを使用
aws s3 sync ./sensitive-data s3://my-bucket/data/ \
  --sse AES256
```

### SSE-KMS（KMS管理キー）

```bash
# デフォルトのKMSキーを使用
aws s3 sync ./confidential s3://my-bucket/confidential/ \
  --sse aws:kms

# 特定のKMSキーIDを指定
aws s3 sync ./top-secret s3://my-bucket/secret/ \
  --sse aws:kms \
  --sse-kms-key-id arn:aws:kms:ap-northeast-1:123456789012:key/12345678-1234-1234-1234-123456789012

# 暗号化コンテキストを追加
aws s3 sync ./protected s3://my-bucket/protected/ \
  --sse aws:kms \
  --sse-kms-key-id alias/my-key \
  --sse-kms-key-id 'project=alpha,environment=production'
```

### SSE-C（顧客提供キー）

```bash
# 顧客提供の暗号化キーを使用（Base64エンコードされたキー）
aws s3 sync ./data s3://my-bucket/data/ \
  --sse-c AES256 \
  --sse-c-key fileb://my-aes-key.bin

# ダウンロード時も同じキーが必要
aws s3 sync s3://my-bucket/data/ ./data \
  --sse-c AES256 \
  --sse-c-key fileb://my-aes-key.bin
```

## メタデータオプション

ファイルのメタデータを設定します。

### カスタムメタデータ

```bash
# メタデータを追加
aws s3 sync ./files s3://my-bucket/files/ \
  --metadata '{"project":"website","version":"2.0"}'

# Content-Typeを指定
aws s3 sync ./html s3://my-bucket/site/ \
  --content-type "text/html; charset=utf-8"

# Cache-Controlを設定
aws s3 sync ./static s3://my-bucket/static/ \
  --cache-control "max-age=86400, public"

# 複数のメタデータを組み合わせ
aws s3 sync ./assets s3://my-bucket/assets/ \
  --cache-control "max-age=31536000" \
  --content-encoding "gzip" \
  --metadata '{"source":"build-pipeline","build":"12345"}'
```

### メタデータディレクティブ

既存のメタデータの扱いを制御します。

```bash
# メタデータをコピー（デフォルト）
aws s3 sync s3://source-bucket/ s3://dest-bucket/ \
  --metadata-directive COPY

# メタデータを置き換え
aws s3 sync s3://source-bucket/ s3://dest-bucket/ \
  --metadata-directive REPLACE \
  --metadata '{"updated":"2024-01-15"}'
```

## パフォーマンス最適化

### マルチパート設定

```bash
# マルチパートのしきい値を設定（デフォルト: 8MB）
aws s3 sync ./large-files s3://my-bucket/files/ \
  --multipart-threshold 16MB

# マルチパートのチャンクサイズを設定（デフォルト: 8MB）
aws s3 sync ./videos s3://my-bucket/videos/ \
  --multipart-chunksize 16MB

# 大容量ファイル用の最適化
aws s3 sync ./bigdata s3://my-bucket/data/ \
  --multipart-threshold 64MB \
  --multipart-chunksize 16MB
```

### 並列処理

```bash
# 同時リクエスト数を増やす（デフォルト: 10）
aws s3 sync ./many-files s3://my-bucket/files/ \
  --max-concurrent-requests 20

# 帯域幅を制限
aws s3 sync ./data s3://my-bucket/data/ \
  --max-bandwidth 10MB/s

# 小さいファイルが多い場合の最適化
aws s3 sync ./images s3://my-bucket/images/ \
  --max-concurrent-requests 50
```

### follow-symlinks オプション

```bash
# シンボリックリンクをたどる
aws s3 sync ./project s3://my-bucket/project/ \
  --follow-symlinks

# シンボリックリンクを無視（デフォルト）
aws s3 sync ./project s3://my-bucket/project/ \
  --no-follow-symlinks
```

## 実践的な使用例

### 静的Webサイトのデプロイ

```bash
#!/bin/bash
# Webサイトをビルドして同期
npm run build

# 古いファイルを削除し、キャッシュ設定を適用
aws s3 sync ./dist s3://my-website-bucket/ \
  --delete \
  --cache-control "max-age=86400, public" \
  --exclude "*.map" \
  --exclude ".DS_Store" \
  --dryrun

# 確認後、実行
aws s3 sync ./dist s3://my-website-bucket/ \
  --delete \
  --cache-control "max-age=86400, public" \
  --exclude "*.map" \
  --exclude ".DS_Store"

# CloudFrontキャッシュを無効化
aws cloudfront create-invalidation \
  --distribution-id E1234EXAMPLE \
  --paths "/*"
```

### バックアップスクリプト

```bash
#!/bin/bash
# 日次バックアップスクリプト
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="backups/$DATE"

# データベースバックアップを作成
mysqldump -u root -p database_name > /tmp/db_backup.sql

# ローカルバックアップディレクトリを作成
mkdir -p /backups/$DATE

# アプリケーションファイルとDBをバックアップ
cp /tmp/db_backup.sql /backups/$DATE/
cp -r /var/www/html /backups/$DATE/

# S3に同期（暗号化してアーカイブストレージクラスに保存）
aws s3 sync /backups/$DATE s3://my-backup-bucket/$BACKUP_PATH \
  --storage-class GLACIER \
  --sse aws:kms \
  --sse-kms-key-id alias/backup-key

# 30日以上前のローカルバックアップを削除
find /backups -type d -mtime +30 -exec rm -rf {} \;

echo "Backup completed: $BACKUP_PATH"
```

### ログファイルの同期

```bash
#!/bin/bash
# ログファイルをS3に同期（新しいログのみ）
LOG_DIR="/var/log/application"
S3_LOG_BUCKET="s3://my-logs-bucket/application-logs"

# 圧縮ログのみ同期（.gzファイル）
aws s3 sync $LOG_DIR $S3_LOG_BUCKET/ \
  --exclude "*" \
  --include "*.gz" \
  --storage-class STANDARD_IA

# 30日後にGlacierに移行するライフサイクルポリシーを設定
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-logs-bucket \
  --lifecycle-configuration file://lifecycle-policy.json
```

### マルチリージョンバックアップ

```bash
#!/bin/bash
# プライマリリージョンからセカンダリリージョンへレプリケーション
PRIMARY_BUCKET="s3://prod-data-us-east-1"
SECONDARY_BUCKET="s3://prod-data-ap-northeast-1"

# 定期的に同期してディザスタリカバリに備える
aws s3 sync $PRIMARY_BUCKET $SECONDARY_BUCKET \
  --source-region us-east-1 \
  --region ap-northeast-1 \
  --storage-class STANDARD_IA \
  --sse aws:kms

echo "Multi-region backup completed at $(date)"
```

### メディアファイルの整理と同期

```bash
#!/bin/bash
# 異なるメディアタイプを異なるストレージクラスに同期

BASE_DIR="./media"
BUCKET="my-media-bucket"

# 高解像度画像（頻繁にアクセス）
aws s3 sync $BASE_DIR/images/high-res s3://$BUCKET/images/high-res/ \
  --exclude "*" \
  --include "*.jpg" \
  --include "*.png" \
  --storage-class STANDARD \
  --cache-control "max-age=2592000"

# サムネイル（低頻度アクセス）
aws s3 sync $BASE_DIR/images/thumbnails s3://$BUCKET/images/thumbnails/ \
  --storage-class STANDARD_IA

# アーカイブ動画（ほとんどアクセスしない）
aws s3 sync $BASE_DIR/videos/archive s3://$BUCKET/videos/archive/ \
  --storage-class GLACIER_IR \
  --exclude "*.tmp" \
  --exclude "*.part"
```

### 開発環境と本番環境の同期

```bash
#!/bin/bash
# ステージング環境から本番環境への安全なデプロイ

STAGING_BUCKET="s3://staging-app-bucket"
PROD_BUCKET="s3://prod-app-bucket"

# まずdryrunで確認
echo "=== Dry run - 変更内容を確認 ==="
aws s3 sync $STAGING_BUCKET $PROD_BUCKET \
  --delete \
  --exclude ".git/*" \
  --exclude "config.dev.json" \
  --exclude "*.test.js" \
  --dryrun

# 確認を求める
read -p "本番環境にデプロイしますか? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
  # バックアップを作成
  BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
  aws s3 sync $PROD_BUCKET s3://prod-backup-bucket/$BACKUP_DATE/

  # デプロイ実行
  aws s3 sync $STAGING_BUCKET $PROD_BUCKET \
    --delete \
    --exclude ".git/*" \
    --exclude "config.dev.json" \
    --exclude "*.test.js" \
    --acl public-read \
    --cache-control "max-age=300"
  
  echo "デプロイ完了"
else
  echo "デプロイをキャンセルしました"
fi
```

### 大規模データセットの効率的な同期

```bash
#!/bin/bash
# 数TB規模のデータセットを効率的に同期

SOURCE_DIR="/mnt/bigdata"
DEST_BUCKET="s3://big-data-bucket/dataset"

# 並列処理を最大化し、マルチパートを最適化
aws s3 sync $SOURCE_DIR $DEST_BUCKET \
  --max-concurrent-requests 50 \
  --multipart-threshold 64MB \
  --multipart-chunksize 16MB \
  --storage-class INTELLIGENT_TIERING \
  --exclude "*.tmp" \
  --exclude ".*" \
  --include "*.parquet" \
  --include "*.csv" \
  --metadata '{"dataset":"analytics","version":"v2.1"}'

# 転送速度を監視
aws s3 sync $SOURCE_DIR $DEST_BUCKET \
  --max-concurrent-requests 50 \
  --multipart-threshold 64MB \
  --multipart-chunksize 16MB \
  2>&1 | tee sync_log_$(date +%Y%m%d).txt
```

## トラブルシューティング

### デバッグモード

```bash
# 詳細なデバッグ情報を表示
aws s3 sync ./data s3://my-bucket/data/ --debug

# より詳細なログ
aws s3 sync ./data s3://my-bucket/data/ --debug 2>&1 | tee sync-debug.log
```

### 一般的な問題と解決策

**問題: 同期が完了しない**
```bash
# タイムアウトを増やす
aws configure set default.s3.max_concurrent_requests 5
aws configure set default.s3.max_bandwidth 5MB/s
aws s3 sync ./data s3://my-bucket/data/
```

**問題: アクセス拒否エラー**
```bash
# IAMポリシーを確認
aws iam get-user-policy --user-name myuser --policy-name S3Access

# バケットポリシーを確認
aws s3api get-bucket-policy --bucket my-bucket

# 適切な権限で再試行
aws s3 sync ./data s3://my-bucket/data/ --profile admin-profile
```

**問題: ファイルが同期されない**
```bash
# フィルタリングルールを確認
aws s3 sync ./data s3://my-bucket/data/ \
  --exclude "*" \
  --include "*.txt" \
  --dryrun

# タイムスタンプとサイズを確認
ls -lh ./data/file.txt
aws s3 ls s3://my-bucket/data/file.txt
```

## ベストプラクティス

### 1. 常に --dryrun を使用して確認

```bash
# 本番環境への変更前に必ず確認
aws s3 sync ./new-content s3://prod-bucket/ --delete --dryrun
```

### 2. 定期的なバックアップの自動化

```bash
# cronジョブで定期実行（毎日午前2時）
0 2 * * * /usr/local/bin/backup-to-s3.sh >> /var/log/s3-backup.log 2>&1
```

### 3. 適切なストレージクラスの選択

```bash
# アクセス頻度に応じて選択
# 頻繁なアクセス: STANDARD
# 月次アクセス: STANDARD_IA
# 年次アクセス: GLACIER
# コンプライアンス: DEEP_ARCHIVE
```

### 4. 暗号化の使用

```bash
# 機密データは必ず暗号化
aws s3 sync ./sensitive s3://my-bucket/sensitive/ \
  --sse aws:kms \
  --sse-kms-key-id alias/sensitive-data-key
```

### 5. コスト最適化

```bash
# 不要なファイルを除外してコスト削減
aws s3 sync ./project s3://my-bucket/project/ \
  --exclude "node_modules/*" \
  --exclude ".git/*" \
  --exclude "*.log" \
  --exclude "*.tmp"
```

## まとめ

`aws s3 sync` は、ローカルとS3間、またはS3バケット間でデータを効率的に同期するための強力なツールです。

**主要なポイント:**
- 差分のみを転送するため効率的
- `--delete` で完全な同期が可能
- `--exclude` / `--include` でフィルタリング
- ストレージクラスと暗号化でコストとセキュリティを最適化
- `--dryrun` で事前確認が可能
- パフォーマンスオプションで大規模データにも対応

**関連コマンド:**
- `aws s3 cp` - 単一ファイルまたは再帰的コピー
- `aws s3 mv` - 移動操作
- `aws s3 rm` - 削除操作
- `aws s3 ls` - リスト表示

**参考リンク:**
- [AWS CLI S3 Sync リファレンス](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html)
- [S3 ストレージクラス](https://aws.amazon.com/s3/storage-classes/)
- [S3 暗号化](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
