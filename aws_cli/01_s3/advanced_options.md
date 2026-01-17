# S3 高度なオプション

## ストレージクラス

### 概要
S3には複数のストレージクラスがあり、コストとアクセス頻度のバランスに応じて選択できます。

| ストレージクラス | 用途 | 取得時間 |
|---|---|---|
| STANDARD | 頻繁にアクセスするデータ | ミリ秒 |
| INTELLIGENT_TIERING | アクセスパターンが不明 | ミリ秒 |
| STANDARD_IA | 低頻度アクセス | ミリ秒 |
| ONEZONE_IA | 低頻度・単一AZ | ミリ秒 |
| GLACIER_IR | アーカイブ（即時取得） | ミリ秒 |
| GLACIER | アーカイブ | 分〜時間 |
| DEEP_ARCHIVE | 長期アーカイブ | 12時間 |

### アップロード時にストレージクラスを指定

```bash
# STANDARD_IA でアップロード
aws s3 cp file.txt s3://my-bucket/ --storage-class STANDARD_IA

# GLACIER でアップロード
aws s3 cp archive.zip s3://my-bucket/ --storage-class GLACIER

# INTELLIGENT_TIERING でアップロード
aws s3 cp data.csv s3://my-bucket/ --storage-class INTELLIGENT_TIERING

# DEEP_ARCHIVE でアップロード（最も低コスト）
aws s3 cp backup.tar.gz s3://my-bucket/ --storage-class DEEP_ARCHIVE
```

### 既存オブジェクトのストレージクラス変更

```bash
# STANDARD から STANDARD_IA に変更
aws s3 cp s3://my-bucket/file.txt s3://my-bucket/file.txt \
  --storage-class STANDARD_IA

# ディレクトリ全体のストレージクラスを変更
aws s3 cp s3://my-bucket/logs/ s3://my-bucket/logs/ \
  --storage-class GLACIER \
  --recursive
```

### Glacierからのデータ復元

```bash
# 復元リクエスト（Standard: 3-5時間）
aws s3api restore-object \
  --bucket my-bucket \
  --key archived-file.zip \
  --restore-request Days=7,GlacierJobParameters={Tier=Standard}

# 高速復元（Expedited: 1-5分）
aws s3api restore-object \
  --bucket my-bucket \
  --key urgent-file.zip \
  --restore-request Days=1,GlacierJobParameters={Tier=Expedited}

# 低コスト復元（Bulk: 5-12時間）
aws s3api restore-object \
  --bucket my-bucket \
  --key bulk-data.tar \
  --restore-request Days=10,GlacierJobParameters={Tier=Bulk}
```

---

## 再帰的操作

### 基本的な再帰操作

```bash
# ディレクトリ全体をアップロード
aws s3 cp local-folder/ s3://my-bucket/folder/ --recursive

# バケット全体をダウンロード
aws s3 cp s3://my-bucket/ ./backup/ --recursive

# ディレクトリ全体を削除
aws s3 rm s3://my-bucket/old-data/ --recursive

# バケット間コピー
aws s3 cp s3://source-bucket/ s3://dest-bucket/ --recursive
```

### 同期操作

```bash
# ローカルからS3へ同期（新規・更新ファイルのみ）
aws s3 sync ./website/ s3://my-bucket/

# S3からローカルへ同期
aws s3 sync s3://my-bucket/ ./local-backup/

# 削除も同期（--delete オプション）
aws s3 sync ./website/ s3://my-bucket/ --delete

# 双方向同期の注意（両方実行すると削除される可能性）
aws s3 sync s3://my-bucket/ ./local/ --delete
aws s3 sync ./local/ s3://my-bucket/ --delete
```

---

## インクルード/エクスクルードパターン

### 基本パターン

```bash
# .txt ファイルのみアップロード
aws s3 cp ./docs/ s3://my-bucket/docs/ \
  --recursive \
  --exclude "*" \
  --include "*.txt"

# .log ファイルを除外してアップロード
aws s3 sync ./app/ s3://my-bucket/app/ \
  --exclude "*.log"

# 複数の拡張子を含める
aws s3 cp ./images/ s3://my-bucket/images/ \
  --recursive \
  --exclude "*" \
  --include "*.jpg" \
  --include "*.png" \
  --include "*.gif"
```

### 高度なパターン

```bash
# 特定のディレクトリを除外
aws s3 sync ./project/ s3://my-bucket/project/ \
  --exclude "node_modules/*" \
  --exclude ".git/*" \
  --exclude "*.log"

# 隠しファイルを除外
aws s3 sync ./data/ s3://my-bucket/data/ \
  --exclude ".*"

# temp ディレクトリ以外をアップロード
aws s3 sync ./ s3://my-bucket/ \
  --exclude "temp/*" \
  --exclude "cache/*"

# 画像以外を除外
aws s3 cp ./media/ s3://my-bucket/media/ \
  --recursive \
  --exclude "*" \
  --include "*.jpg" \
  --include "*.jpeg" \
  --include "*.png" \
  --include "*.webp"
```

### パターンの評価順序

```bash
# 評価は左から右へ、最後のマッチが適用される
# 例: すべて除外してから .pdf のみ含める
aws s3 cp ./documents/ s3://my-bucket/docs/ \
  --recursive \
  --exclude "*" \
  --include "*.pdf"

# 例: すべて含めてから .tmp を除外
aws s3 sync ./backup/ s3://my-bucket/backup/ \
  --include "*" \
  --exclude "*.tmp"
```

---

## ACL（アクセスコントロールリスト）オプション

### 事前定義されたACL

```bash
# プライベート（デフォルト）
aws s3 cp file.txt s3://my-bucket/ --acl private

# パブリック読み取り可能
aws s3 cp index.html s3://my-bucket/ --acl public-read

# パブリック読み書き可能（非推奨）
aws s3 cp shared.txt s3://my-bucket/ --acl public-read-write

# 認証ユーザーのみ読み取り可能
aws s3 cp document.pdf s3://my-bucket/ --acl authenticated-read

# バケット所有者にフルコントロール
aws s3 cp report.csv s3://my-bucket/ --acl bucket-owner-full-control
```

### ACLの種類

| ACL | 説明 |
|---|---|
| private | 所有者のみアクセス可能（デフォルト） |
| public-read | 誰でも読み取り可能 |
| public-read-write | 誰でも読み書き可能（非推奨） |
| authenticated-read | AWSアカウント所有者のみ読み取り可能 |
| bucket-owner-read | バケット所有者が読み取り可能 |
| bucket-owner-full-control | バケット所有者がフルコントロール |

### 既存オブジェクトのACL変更

```bash
# 単一ファイルのACLを変更
aws s3api put-object-acl \
  --bucket my-bucket \
  --key file.txt \
  --acl public-read

# 再帰的にACLを変更
aws s3 cp s3://my-bucket/public/ s3://my-bucket/public/ \
  --recursive \
  --acl public-read \
  --metadata-directive REPLACE
```

---

## HTTPヘッダー

### Content-Type

```bash
# HTMLファイルとしてアップロード
aws s3 cp index.html s3://my-bucket/ \
  --content-type "text/html; charset=utf-8"

# JSONファイルとしてアップロード
aws s3 cp data.json s3://my-bucket/ \
  --content-type "application/json"

# CSSファイルとしてアップロード
aws s3 cp style.css s3://my-bucket/ \
  --content-type "text/css"

# JavaScriptファイルとしてアップロード
aws s3 cp app.js s3://my-bucket/ \
  --content-type "application/javascript"
```

### Cache-Control

```bash
# 1時間キャッシュ
aws s3 cp logo.png s3://my-bucket/ \
  --cache-control "max-age=3600"

# 1日キャッシュ
aws s3 cp style.css s3://my-bucket/ \
  --cache-control "max-age=86400"

# 1年キャッシュ（静的アセット）
aws s3 cp app-v1.2.3.js s3://my-bucket/static/ \
  --cache-control "max-age=31536000, immutable"

# キャッシュ無効
aws s3 cp index.html s3://my-bucket/ \
  --cache-control "no-cache, no-store, must-revalidate"

# パブリックキャッシュ
aws s3 cp public-data.json s3://my-bucket/ \
  --cache-control "public, max-age=3600"
```

### Content-Encoding

```bash
# gzip圧縮済みファイル
aws s3 cp file.txt.gz s3://my-bucket/file.txt \
  --content-encoding gzip \
  --content-type "text/plain"

# Brotli圧縮済みファイル
aws s3 cp bundle.js.br s3://my-bucket/bundle.js \
  --content-encoding br \
  --content-type "application/javascript"
```

### Content-Disposition

```bash
# ダウンロード時のファイル名を指定
aws s3 cp report.pdf s3://my-bucket/ \
  --content-disposition 'attachment; filename="monthly-report.pdf"'

# インラインで表示
aws s3 cp image.jpg s3://my-bucket/ \
  --content-disposition "inline"
```

### 複数のヘッダーを組み合わせ

```bash
# 静的アセット用の最適設定
aws s3 cp bundle.js s3://my-bucket/static/ \
  --content-type "application/javascript" \
  --cache-control "public, max-age=31536000, immutable" \
  --acl public-read

# HTMLファイル用の設定
aws s3 cp index.html s3://my-bucket/ \
  --content-type "text/html; charset=utf-8" \
  --cache-control "no-cache, no-store, must-revalidate" \
  --acl public-read

# 画像ファイル用の設定
aws s3 cp logo.png s3://my-bucket/images/ \
  --content-type "image/png" \
  --cache-control "public, max-age=604800" \
  --acl public-read
```

### メタデータの追加

```bash
# カスタムメタデータを追加
aws s3 cp file.txt s3://my-bucket/ \
  --metadata author=John,version=1.0,environment=production

# メタデータを含めて複数のヘッダーを設定
aws s3 cp document.pdf s3://my-bucket/ \
  --content-type "application/pdf" \
  --cache-control "max-age=3600" \
  --metadata title="User Manual",category=documentation
```

---

## パフォーマンスチューニングオプション

### マルチパート設定

```bash
# マルチパートのしきい値を設定（デフォルト: 8MB）
aws s3 cp large-file.zip s3://my-bucket/ \
  --multipart-threshold 16MB

# マルチパートのチャンクサイズを設定（デフォルト: 8MB）
aws s3 cp video.mp4 s3://my-bucket/ \
  --multipart-chunksize 16MB

# 大容量ファイル用の最適化
aws s3 cp huge-dataset.tar.gz s3://my-bucket/ \
  --multipart-threshold 64MB \
  --multipart-chunksize 64MB
```

### 並列処理

```bash
# 最大同時リクエスト数を設定（デフォルト: 10）
aws s3 cp ./files/ s3://my-bucket/files/ \
  --recursive \
  --max-concurrent-requests 20

# 最大帯域幅を制限（MB/s）
aws s3 cp large-backup.tar s3://my-bucket/ \
  --max-bandwidth 50MB/s

# 最大キュー数を設定
aws s3 sync ./data/ s3://my-bucket/data/ \
  --max-queue-size 2000
```

### 総合的なパフォーマンス最適化

```bash
# 高速アップロード設定
aws s3 cp ./big-data/ s3://my-bucket/big-data/ \
  --recursive \
  --multipart-threshold 64MB \
  --multipart-chunksize 64MB \
  --max-concurrent-requests 20

# 帯域幅制限付き同期
aws s3 sync ./backup/ s3://my-bucket/backup/ \
  --max-bandwidth 10MB/s \
  --max-concurrent-requests 5

# 小ファイル大量アップロード最適化
aws s3 sync ./images/ s3://my-bucket/images/ \
  --max-concurrent-requests 50 \
  --max-queue-size 10000
```

### 設定ファイルでデフォルト値を変更

`~/.aws/config` に追加:

```ini
[default]
s3 =
  max_concurrent_requests = 20
  max_queue_size = 10000
  multipart_threshold = 64MB
  multipart_chunksize = 16MB
  max_bandwidth = 50MB/s
```

### リトライ設定

```bash
# 最大リトライ回数を設定
aws s3 cp file.txt s3://my-bucket/ \
  --cli-read-timeout 300 \
  --cli-connect-timeout 60

# AWS CLIの設定ファイルで設定
# ~/.aws/config
# [default]
# retry_mode = adaptive
# max_attempts = 10
```

---

## 実践的な組み合わせ例

### 静的ウェブサイトのデプロイ

```bash
# HTML/CSS/JSを適切なヘッダーで一括アップロード
aws s3 sync ./dist/ s3://my-website-bucket/ \
  --delete \
  --cache-control "no-cache" \
  --exclude "*" \
  --include "*.html"

aws s3 sync ./dist/ s3://my-website-bucket/ \
  --cache-control "max-age=31536000" \
  --exclude "*" \
  --include "*.js" \
  --include "*.css" \
  --include "*.png" \
  --include "*.jpg" \
  --include "*.svg"
```

### バックアップシステム

```bash
# 毎日のバックアップ（STANDARD_IA）
aws s3 sync /data/daily/ s3://backup-bucket/daily/ \
  --storage-class STANDARD_IA \
  --exclude "*.tmp" \
  --exclude "*.log"

# 月次バックアップ（GLACIER）
aws s3 sync /data/monthly/ s3://backup-bucket/monthly/ \
  --storage-class GLACIER \
  --multipart-threshold 100MB \
  --multipart-chunksize 100MB

# 年次バックアップ（DEEP_ARCHIVE）
aws s3 cp /data/yearly/archive-2024.tar.gz s3://backup-bucket/yearly/ \
  --storage-class DEEP_ARCHIVE
```

### メディアファイルの配信

```bash
# 画像ファイルの最適化アップロード
aws s3 sync ./images/ s3://cdn-bucket/images/ \
  --cache-control "public, max-age=2592000" \
  --content-type "image/jpeg" \
  --acl public-read \
  --exclude "*" \
  --include "*.jpg" \
  --include "*.jpeg"

# 動画ファイルの最適化アップロード
aws s3 cp video.mp4 s3://cdn-bucket/videos/ \
  --cache-control "public, max-age=31536000" \
  --content-type "video/mp4" \
  --multipart-threshold 100MB \
  --multipart-chunksize 100MB \
  --acl public-read
```

---

## トラブルシューティング

### アップロードの高速化

```bash
# 並列処理を最大化
aws configure set default.s3.max_concurrent_requests 100
aws configure set default.s3.multipart_chunksize 25MB

# 転送速度の確認
aws s3 cp large-file.zip s3://my-bucket/ --debug 2>&1 | grep -i "transfer"
```

### メタデータの確認

```bash
# オブジェクトのメタデータを表示
aws s3api head-object \
  --bucket my-bucket \
  --key file.txt

# ストレージクラスを確認
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query "Contents[?StorageClass=='GLACIER'].[Key,StorageClass]" \
  --output table
```

### ACL設定の確認

```bash
# オブジェクトのACLを確認
aws s3api get-object-acl \
  --bucket my-bucket \
  --key file.txt
```

---

## ベストプラクティス

1. **ストレージクラスの選択**
   - 頻繁にアクセス: STANDARD
   - 低頻度アクセス: STANDARD_IA
   - アーカイブ: GLACIER / DEEP_ARCHIVE
   - 不明な場合: INTELLIGENT_TIERING

2. **パフォーマンス最適化**
   - 大容量ファイル: マルチパート設定を調整
   - 小ファイル大量: 並列処理数を増やす
   - 帯域幅制限: `--max-bandwidth` を使用

3. **セキュリティ**
   - デフォルトは `private` ACL を使用
   - パブリックアクセスは必要最小限に
   - バケットポリシーと併用を推奨

4. **キャッシュ戦略**
   - HTML: `no-cache`
   - 静的アセット（バージョン付き）: `max-age=31536000`
   - 画像: `max-age=604800`（1週間）

5. **コスト最適化**
   - ライフサイクルポリシーと組み合わせ
   - 不要なデータは `--delete` で削除
   - ストレージクラスを適切に選択
