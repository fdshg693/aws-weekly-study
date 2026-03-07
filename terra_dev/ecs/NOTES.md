# Docker Image管理: AWS ECR + ECS Fargate向けベストプラクティスとピットフォール集

## 目次

1. [クロスプラットフォーム/アーキテクチャ問題](#1-クロスプラットフォームアーキテクチャ問題)
2. [OCI vs Dockerマニフェスト形式の問題](#2-oci-vs-dockerマニフェスト形式の問題)
3. [イメージタグ戦略](#3-イメージタグ戦略)
4. [イメージサイズの最適化](#4-イメージサイズの最適化)
5. [レイヤーキャッシュの考慮事項](#5-レイヤーキャッシュの考慮事項)
6. [ECRライフサイクルポリシー](#6-ecrライフサイクルポリシー)
7. [イメージ脆弱性スキャン](#7-イメージ脆弱性スキャン)
8. [マルチステージビルド](#8-マルチステージビルド)
9. [.dockerignore](#9-dockerignore)
10. [ベースイメージの選択](#10-ベースイメージの選択)
11. [Docker BuildKit vs レガシービルダー](#11-docker-buildkit-vs-レガシービルダー)
12. [ダイジェストピンニング](#12-ダイジェストピンニング)
13. [Buildxとマルチプラットフォームマニフェスト](#13-buildxとマルチプラットフォームマニフェスト)
14. [ECS固有の考慮事項](#14-ecs固有の考慮事項)

---

## 1. クロスプラットフォーム/アーキテクチャ問題

### 問題の本質

Mac（M1/M2/M3/M4 = Apple Silicon = ARM64）でビルドしたDockerイメージは、
デフォルトで`linux/arm64`アーキテクチャになる。
一方、ECS Fargateは通常`linux/amd64`（x86_64）で動作するため、**そのままpushすると動かない**。

### よくあるエラーメッセージ

```
exec format error
```

```
WARNING: The requested image's platform (linux/amd64) does not match
the detected host platform (linux/arm64/v8)
```

### 解決策

#### 方法1: `--platform`フラグを指定してビルド（最も簡単）

```bash
docker build --platform linux/amd64 -t my-app .
```

#### 方法2: `docker buildx`でマルチプラットフォームビルド（推奨）

```bash
# ビルダーの作成（初回のみ）
docker buildx create --name multiarch --use

# マルチプラットフォームビルド＆プッシュ
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t <account>.dkr.ecr.<region>.amazonaws.com/my-app:v1.0 \
  --push .
```

#### 方法3: Docker DesktopでRosettaエミュレーションを有効化

Docker Desktop → Settings → Features in development → "Use Rosetta for x86/amd64 emulation on Apple Silicon" にチェック。QEMUより高速。

### 重要な注意点

- **CI/CDでビルドするのがベストプラクティス**。ローカルMacでビルド→pushは開発時のみに留める
- Fargateは2024年以降ARM64（Graviton）にも対応しているが、タスク定義で`runtimePlatform`の明示的な指定が必要
- `--platform`を忘れると、pushは成功するがコンテナ起動時に`exec format error`で失敗する（push時にはエラーにならないのが罠）

---

## 2. OCI vs Dockerマニフェスト形式の問題

### 背景

Dockerイメージのマニフェスト形式には主に以下がある:

| 形式 | メディアタイプ | 備考 |
|------|-------------|------|
| Docker V2 Schema 2 | `application/vnd.docker.distribution.manifest.v2+json` | 従来の標準 |
| OCI Image Manifest | `application/vnd.oci.image.manifest.v1+json` | 新しい標準 |
| OCI Image Index | `application/vnd.oci.image.index.v1+json` | マルチプラットフォーム用 |

### ECRの対応状況

ECRはDocker V2 Schema 1/2、OCI v1.0以降の全てをサポートしている。
ただし、**ECRと連携する他のAWSサービスで問題が発生する**ことがある:

- **SageMaker**: OCI Image Indexをサポートしない（`Unsupported manifest media type`エラー）
- **Lambda**: OCI形式のコンテナイメージで問題が発生するケースがある

### BuildKit v0.11以降のデフォルト変更（重大な落とし穴）

BuildKit v0.11以降、ビルド時にデフォルトで**provenance attestation**が付与されるようになった。
これにより:

- イメージが`OCI Image Index`形式でpushされる
- 一部のAWSサービスで互換性問題が発生する
- ECRのセキュリティスキャンが失敗する場合がある

### 解決策

```bash
# provenance を無効化してビルド
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  -t <account>.dkr.ecr.<region>.amazonaws.com/my-app:v1.0 \
  --push .

# さらに確実にDocker V2形式にする場合
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --output=type=image,push=true,oci-mediatypes=false \
  -t <account>.dkr.ecr.<region>.amazonaws.com/my-app:v1.0 .

# 環境変数でグローバルに無効化
export BUILDX_NO_DEFAULT_ATTESTATIONS=1
```

### まとめ

- **ECR自体はOCI対応済み**だが、downstream（SageMaker、Lambda等）で問題が起きうる
- **BuildKit v0.11以降は`--provenance=false`を付けるのが安全**（特にCI/CD環境で）
- GitHub ActionsのDocker build-push-actionでも同様の問題が報告されている

---

## 3. イメージタグ戦略

### `:latest`タグの落とし穴

| 問題 | 詳細 |
|------|------|
| どのバージョンが動いているか不明 | デバッグ・障害調査時に困る |
| ロールバックが困難 | 前のバージョンに戻せない |
| キャッシュの問題 | ECSが古いイメージをキャッシュして使い続ける場合がある |
| 再現性がない | 同じタグでも中身が変わる |

### 推奨タグ戦略

```bash
# Git SHAタグ（最も推奨）
docker tag my-app:latest <ecr-url>/my-app:abc1234

# セマンティックバージョニング
docker tag my-app:latest <ecr-url>/my-app:v1.2.3

# 日付＋ビルド番号
docker tag my-app:latest <ecr-url>/my-app:20260228-build42

# 複数タグの併用（利便性と追跡性の両立）
docker tag my-app:latest <ecr-url>/my-app:v1.2.3
docker tag my-app:latest <ecr-url>/my-app:abc1234
docker tag my-app:latest <ecr-url>/my-app:latest  # 参考用
```

### ECRのImmutable Tags（不変タグ）設定

```hcl
# Terraform
resource "aws_ecr_repository" "app" {
  name                 = "my-app"
  image_tag_mutability = "IMMUTABLE"  # 同じタグでの上書きを禁止
}
```

**メリット**:
- 同じタグで異なるイメージが上書きされることを防止
- セキュリティ攻撃（悪意あるイメージの差し替え）を防止
- 監査証跡が確実になる

**注意**: IMMUTABLEに設定すると`:latest`タグの運用は不可能になる（上書きできないため）。
これは意図的な制約であり、本番環境では推奨される設定。

---

## 4. イメージサイズの最適化

### なぜサイズを小さくすべきか

- **デプロイ速度**: Fargateのタスク起動時間に直結（イメージpull時間）
- **ストレージコスト**: ECRの料金はストレージ量に比例
- **攻撃対象面積の縮小**: パッケージが少ない = 脆弱性が少ない
- **ネットワーク帯域**: 特にクロスリージョンの場合に顕著

### サイズ比較（目安）

| ベースイメージ | サイズ | 用途 |
|-------------|--------|------|
| `ubuntu:22.04` | ~77MB | 開発時のデバッグ用 |
| `node:20` | ~1.1GB | 非推奨（巨大すぎる） |
| `node:20-alpine` | ~130MB | Node.jsアプリ向け |
| `node:20-slim` | ~200MB | glibc依存がある場合 |
| `nginx:alpine` | ~40MB | 静的ファイル配信 |
| `gcr.io/distroless/nodejs20` | ~130MB | 本番向け（シェルなし） |
| `scratch` | 0MB | Go等のスタティックバイナリ向け |

### 最適化テクニック

```dockerfile
# Bad: レイヤーが増える
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# Good: 1レイヤーにまとめ、キャッシュも削除
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

---

## 5. レイヤーキャッシュの考慮事項

### 基本原則: 変更頻度が低いものを上に

```dockerfile
# Good: 依存関係ファイルを先にコピー → npm installをキャッシュ
COPY package.json package-lock.json ./
RUN npm ci --production
COPY . .

# Bad: 全ファイルを先にコピー → ソース変更のたびにnpm installが再実行
COPY . .
RUN npm ci --production
```

### BuildKitのキャッシュマウント

```dockerfile
# npm/yarnのキャッシュをビルド間で保持
RUN --mount=type=cache,target=/root/.npm \
    npm ci --production
```

### ECR/CI環境でのキャッシュ戦略

```bash
# ECRをキャッシュソースとして使う
docker buildx build \
  --cache-from type=registry,ref=<ecr-url>/my-app:cache \
  --cache-to type=registry,ref=<ecr-url>/my-app:cache,mode=max \
  --platform linux/amd64 \
  -t <ecr-url>/my-app:v1.0 \
  --push .
```

---

## 6. ECRライフサイクルポリシー

### なぜ必要か

ライフサイクルポリシーを設定しないと、古いイメージが際限なく蓄積し、ストレージコストが増加する。

### 推奨ポリシー例

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "本番イメージを直近30個保持",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "dev用イメージを直近10個保持",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["dev-"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 10,
      "description": "タグなしイメージを7日後に削除",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    }
  ]
}
```

### Terraform での設定

```hcl
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy     = file("ecr-lifecycle-policy.json")
}
```

### 注意点

- **ポリシーの適用前にプレビューで確認すること**（意図しないイメージの削除を防ぐ）
- `"any"` や `"untagged"` ルールは1つのポリシーにつき1つだけ
- `"untagged"` ルールは最も低い優先度にする必要がある
- ライフサイクルポリシーは非同期で実行される（即時削除ではない）

---

## 7. イメージ脆弱性スキャン

### ECRの2つのスキャンオプション

| 機能 | Basic Scanning | Enhanced Scanning (Inspector) |
|------|---------------|-------------------------------|
| スキャンエンジン | Clair (オープンソース) | Amazon Inspector |
| 対象 | OS パッケージ | OS パッケージ + 言語パッケージ（npm, pip等） |
| トリガー | push時 / 手動 | 継続的（自動） |
| コスト | 無料 | 有料 |

### 推奨設定

```hcl
# Terraform: push時の自動スキャン有効化
resource "aws_ecr_repository" "app" {
  name = "my-app"
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

### CI/CDでの運用

- CI/CDパイプラインでスキャン結果をチェックし、**CRITICALな脆弱性がある場合はデプロイを中止する**
- `trivy`等のサードパーティツールをCI中に追加で実行するのも効果的
- push前のローカルスキャン: `docker scout cves my-app:latest`

---

## 8. マルチステージビルド

### 基本パターン

```dockerfile
# ===== ビルドステージ =====
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# ===== 実行ステージ =====
FROM node:20-alpine AS runner
WORKDIR /app
# ビルド成果物のみコピー（devDependenciesやソースコードは含まない）
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
EXPOSE 3000
USER node
CMD ["node", "dist/index.js"]
```

### 静的サイトの場合（Nginx配信）

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Goアプリケーションの場合（極小イメージ）

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app .

FROM scratch
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]
```

### ポイント

- ビルドに必要なツール（コンパイラ、devDependencies等）は最終イメージに含めない
- BuildKitは独立したステージを**自動で並列実行**する
- `--target`フラグで特定のステージまでのビルドが可能（開発用とプロダクション用の切り替え）

---

## 9. .dockerignore

### なぜ重要か

`.dockerignore`がないと、ビルドコンテキストに不要なファイルが全て含まれ:
- ビルドが遅くなる（巨大な`node_modules`や`.git`の転送）
- イメージサイズが無駄に大きくなる
- **機密情報がイメージに入ってしまう危険性**（`.env`、秘密鍵等）

### 推奨 .dockerignore

```gitignore
# バージョン管理
.git
.gitignore

# 依存関係（コンテナ内で再インストールする）
node_modules

# ビルド成果物（マルチステージビルドで生成する）
dist
build
.next

# 環境設定・機密情報
.env
.env.*
*.pem
*.key

# 開発ツール
.vscode
.idea
*.swp
*.swo

# テスト
coverage
__tests__
*.test.js
*.spec.js

# Docker関連
Dockerfile
docker-compose*.yml
.dockerignore

# ドキュメント
README.md
CHANGELOG.md
docs/

# OS固有
.DS_Store
Thumbs.db
```

### 落とし穴

- `.dockerignore`はビルドコンテキストのルートに置かなければならない
- `COPY . .`を使う場合は必ず`.dockerignore`を用意する
- `.git`ディレクトリを除外し忘れると、数百MBが余計にイメージに含まれる場合がある

---

## 10. ベースイメージの選択

### 選択基準

| イメージ | 特徴 | 適用場面 |
|---------|------|---------|
| **Alpine** | 小さい(~5MB)、musl libc | 多くのケースで推奨 |
| **Slim** (Debian系) | 中程度のサイズ、glibc | glibc依存がある場合 |
| **Distroless** (Google) | シェルなし、最小限 | セキュリティ重視の本番環境 |
| **Scratch** | 完全に空 | Go等のスタティックバイナリ |
| **Chainguard** | セキュリティ重視、頻繁な更新 | エンタープライズ向け |

### Alpineの注意点

- `musl libc`を使っているため、一部のC拡張ライブラリで互換性問題が発生する
- Pythonの一部パッケージ（numpy等）はAlpineだとビルドに時間がかかる場合がある
- DNSの解決動作がglibcと微妙に異なる

### Distrolessの注意点

- シェルがないためコンテナにexecで入れない（デバッグが困難）
- `:debug`タグ版にはbusyboxシェルが含まれる（開発時はこちらを使う）
- パッケージマネージャがないため、追加のツールインストール不可

---

## 11. Docker BuildKit vs レガシービルダー

### BuildKitの利点

| 機能 | レガシー | BuildKit |
|------|---------|----------|
| 並列ビルド | 不可 | ステージの自動並列実行 |
| キャッシュマウント | 不可 | `--mount=type=cache` |
| シークレットマウント | 不可 | `--mount=type=secret` |
| SSH転送 | 不可 | `--mount=type=ssh` |
| 圧縮効率 | 標準 | zstd対応でより効率的 |
| セキュリティ | 中間イメージが残る | 中間イメージなし |

### 有効化方法

```bash
# 環境変数で有効化
export DOCKER_BUILDKIT=1

# Docker Desktop 23.0以降はデフォルトで有効

# docker-composeの場合
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build
```

### BuildKitの落とし穴

- **provenance attestationのデフォルト有効化**（前述のOCIマニフェスト問題）
- `--output`の仕様がレガシーと異なる
- 一部の古いDockerfile構文で非互換がある場合がある

---

## 12. ダイジェストピンニング

### ダイジェストとは

イメージの内容のSHA-256ハッシュ値。タグと異なり、**イメージの中身が変われば必ず変わる**。

### ピンニングの方法

```dockerfile
# タグのみ（再現性なし: 同じタグでも中身が変わりうる）
FROM nginx:alpine

# ダイジェスト付き（完全な再現性）
FROM nginx:alpine@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
```

### ダイジェストの確認方法

```bash
# ローカルイメージのダイジェスト
docker inspect --format='{{index .RepoDigests 0}}' nginx:alpine

# リモートイメージのダイジェスト
docker manifest inspect nginx:alpine | jq '.config.digest'

# ECR内のダイジェスト
aws ecr describe-images --repository-name my-app \
  --query 'imageDetails[*].{tag:imageTags,digest:imageDigest}'
```

### トレードオフ

| メリット | デメリット |
|---------|----------|
| 完全な再現性 | セキュリティパッチの自動適用ができない |
| サプライチェーン攻撃の防止 | 更新作業が手動（手間） |
| 監査可能 | ダイジェストの管理が複雑 |

### 推奨アプローチ

- **本番環境**: ダイジェストピンニングを使用し、Docker ScoutやDependabot等で更新PRを自動生成
- **開発環境**: タグ指定で十分（例: `nginx:1.25-alpine`）
- メジャーバージョンだけのタグ（例: `node:20`）は避ける（パッチバージョン含めて指定する）

---

## 13. Buildxとマルチプラットフォームマニフェスト

### セットアップ

```bash
# 新しいビルダーインスタンスを作成
docker buildx create --name mybuilder --use

# ビルダーの状態確認
docker buildx inspect --bootstrap
```

### マルチプラットフォームビルド＆プッシュ

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --provenance=false \
  -t <ecr-url>/my-app:v1.0 \
  --push .
```

### 重要な注意点

- `--push`を付けない場合、マルチプラットフォームイメージはローカルに保存できない（manifest listはレジストリにしか格納できない）
- `--load`は単一プラットフォームのみ対応
- Fargateでarm64を使う場合、タスク定義で`runtimePlatform`の指定が必要:

```json
{
  "runtimePlatform": {
    "cpuArchitecture": "ARM64",
    "operatingSystemFamily": "LINUX"
  }
}
```

---

## 14. ECS固有の考慮事項

### タスク定義でのイメージ指定

#### `:latest`タグの罠（ECS特有の挙動）

ECSはサービスのデプロイ時にイメージタグを**ダイジェストに解決（resolve）して固定する**。
つまり:

1. タスク定義で`my-app:latest`を指定
2. ECRに新しい`my-app:latest`をpush
3. **ECSは古いダイジェストのまま新しいタスクを起動する**（新しいイメージを使わない）

#### 解決策

```bash
# 方法1: Force New Deployment（タグを変えずに最新のダイジェストでデプロイ）
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --force-new-deployment

# 方法2: 新しいタスク定義リビジョンを作成してデプロイ（推奨）
# イメージタグを一意にする（例: git SHA）
```

### Fargateのイメージpull動作

- Fargateはタスク起動のたびにECRからイメージをpullする（EC2起動タイプとは異なりローカルキャッシュなし）
- **イメージサイズが起動時間に直結する**（大きいイメージ = 起動が遅い）
- VPCエンドポイント（PrivateLink）を使うと、インターネット経由のpullを避けられる
- **イメージはECSクラスターと同じリージョンのECRに配置すること**（クロスリージョンpullは遅い）

### VPCエンドポイント設定

Fargateタスクがプライベートサブネットにある場合、以下のVPCエンドポイントが必要:

| エンドポイント | 用途 |
|-------------|------|
| `com.amazonaws.<region>.ecr.dkr` | イメージのpull |
| `com.amazonaws.<region>.ecr.api` | ECR API呼び出し |
| `com.amazonaws.<region>.s3` (Gateway型) | イメージレイヤーの取得（S3経由） |
| `com.amazonaws.<region>.logs` | CloudWatch Logsへのログ送信 |

### IAMロール

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage"
  ],
  "Resource": "*"
}
```

### ECRログイン（push前に必須）

```bash
# 認証トークンの取得とログイン
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com

# 認証トークンは12時間で期限切れ（CI/CDでは毎回実行すること）
```

---

## よくあるトラブルシューティングチェックリスト

問題が発生した場合の確認順序:

1. **イメージのアーキテクチャは正しいか？** → `docker inspect`で確認
2. **マニフェスト形式は互換性があるか？** → `--provenance=false`を試す
3. **ECRの認証トークンは有効か？** → 12時間の期限切れに注意
4. **タスクのIAMロールにECR権限があるか？**
5. **VPCエンドポイントは設定されているか？**（プライベートサブネットの場合）
6. **イメージタグは正しいリビジョンを指しているか？** → ダイジェストで確認
7. **Fargateのリソース（CPU/メモリ）は十分か？**
8. **セキュリティグループでアウトバウンドは許可されているか？**

---

## 参考リンク

- [AWS ECS Container Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/container-considerations.html)
- [AWS ECS Security Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-tasks-containers.html)
- [ECR Image Manifest Format Support](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-manifest-formats.html)
- [ECR Lifecycle Policy Examples](https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_examples.html)
- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [OCI Image and Distribution 1.1 Support in Amazon ECR](https://aws.amazon.com/blogs/opensource/diving-into-oci-image-and-distribution-1-1-support-in-amazon-ecr/)
- [ECS Software Version Consistency](https://aws.amazon.com/blogs/containers/announcing-software-version-consistency-for-amazon-ecs-services/)
- [Fargate Image Pull Behavior](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-pull-behavior.html)
- [Docker Buildx Platform Mismatch Fix](https://pythonspeed.com/articles/docker-build-problems-mac/)
- [BuildKit Provenance Attestation Issue](https://github.com/docker/buildx/issues/1533)
- [ECR Immutable Tags](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html)
