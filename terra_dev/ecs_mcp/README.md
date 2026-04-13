# ECS Fargate + FastMCP + Keycloak on AWS サンプル

`python/main.py` にある FastMCP サーバーを Docker 化し、ECR / ECS Fargate / ALB / ACM / **Keycloak(OIDC/OAuth 2.1)** で公開する学習用サンプルです。
Keycloak 本体もこの Terraform で **AWS 上に管理** できるようにしてあります。

## 何を作るか

```text
クライアント
  ↓ HTTPS
ALB
  ├─ /keycloak/* → Keycloak ECS Fargate タスクへ転送
  ├─ /mcp    → ECS Fargate タスクへ転送
  └─ /health → 認証なしで ECS Fargate タスクへ転送
        ↓
Starlette ベースの MCP Gateway
  ├─ /mcp    → FastMCP (streamable HTTP)
  ├─ /health
  └─ /.well-known/*
        ↓
CloudWatch Logs / Container Insights

別系統:

```text
ALB
  └─ /keycloak/* → Keycloak ECS Fargate
                       ↓
                 RDS PostgreSQL
```
```

## 設計のポイント

- **Keycloak 前提の認証構成**
  - MCP クライアント向け: サーバーサイド OAuth + Keycloak token introspection
- **Keycloak も AWS 管理**
  - 同じ VPC 内に Keycloak 用 ECS サービスと RDS PostgreSQL を作成
  - ALB の `/keycloak` 配下で公開し、MCP サーバーから同一構成で参照する
- **HTTPS 終端**
  - ALB に ACM 証明書を設定
  - HTTP(80) は HTTPS(443) へリダイレクト
- **MCP 仕様準拠のメタデータ配信**
  - `/.well-known/oauth-protected-resource`
  - `/.well-known/oauth-authorization-server`
  - `WWW-Authenticate: Bearer resource_metadata=...` を返す
- **スケールしやすさ**
  - `stateless_http=true` で FastMCP を起動
  - ALB 配下で複数タスクへ広げやすい構成にしている

## ファイル構成

| ファイル | 内容 |
|---|---|
| `provider.tf` | AWS プロバイダ設定 |
| `variables.tf` | 変数定義（ACM / Keycloak / Route53 / RDS / ECS など） |
| `vpc.tf` | VPC / Subnet / IGW / NAT Gateway / Route Table |
| `security_groups.tf` | ALB 用 / ECS 用セキュリティグループ |
| `ecr.tf` | ECR リポジトリ |
| `iam.tf` | ECS タスク実行ロール |
| `keycloak.tf` | Keycloak realm / endpoint / audience 解決用 locals |
| `keycloak_aws.tf` | Keycloak 用 ECS / RDS / ALB ルーティング |
| `alb.tf` | ALB / Target Group / Listener / Listener Rule / 任意の Route53 レコード |
| `ecs.tf` | ECS Cluster / Task Definition / Service / CloudWatch Logs |
| `outputs.tf` | 主要な出力値 |
| `docker/Dockerfile` | FastMCP コンテナ化 |
| `docker/server.py` | Uvicorn のエントリポイント |
| `docker/mcp_gateway/` | 設定・認証・ASGI ルーティング |
| `docker/requirements.txt` | Docker 用 Python 依存 |
| `dev.tfvars` | 開発用変数例 |
| `prod.tfvars` | 本番用変数例 |

## apply 前に必要な前提

このディレクトリだけでは完結しないものは、すべて変数化しています。

### 1. ACM 証明書

- 変数: `acm_certificate_arn`
- ALB と **同じリージョン** の ACM 証明書が必要
- 独自ドメインで使うなら、証明書の CN/SAN と `app_domain_name` を一致させる

### 2. Keycloak

このプロジェクトでは、既定で Keycloak を **AWS 上に一緒に構築** する。
構成は以下のとおり。

- Keycloak 本体: ECS Fargate
- データベース: RDS PostgreSQL
- 公開経路: 既存 ALB の `/keycloak/*`

そのため、`deploy_keycloak_on_aws = true` の場合、`keycloak_base_url` は手で指定せず
`https://<app_domain_name>/keycloak` が自動で使われる。

ただし、**realm / client / scope の中身までは Terraform ではまだ投入していない** ため、初回起動後に
Keycloak Admin Console で少なくとも以下の client を作成する。

- **MCP クライアント用 public client**（事前登録運用の場合）
  - Redirect URI: `https://claude.ai/api/mcp/auth_callback`
- **Token introspection 用 confidential client**
  - MCP Gateway が Keycloak introspection endpoint を呼ぶための client

代表的な変数:

- `deploy_keycloak_on_aws`
- `keycloak_path`
- `keycloak_admin_username`
- `keycloak_admin_password`
- `keycloak_db_password`
- `keycloak_base_url`
- `keycloak_realm`
- `keycloak_public_client_id`
- `keycloak_introspection_client_id`
- `keycloak_introspection_client_secret`
- `keycloak_enable_dynamic_client_registration`

Keycloak の Dynamic Client Registration を使う場合は `keycloak_enable_dynamic_client_registration = true` にする。
使わない場合は、MCP Gateway の `/oauth/register` が事前登録済みの `keycloak_public_client_id` を返す。

既存の外部 Keycloak を使いたい場合は、`deploy_keycloak_on_aws = false` にして `keycloak_base_url` を指定すれば従来どおり動く。

### 3. Route53 Hosted Zone（任意）

- 変数:
  - `create_route53_record`
  - `route53_zone_id`
  - `app_domain_name`
- `create_route53_record = true` にすると ALB 向け Alias レコードを作成する
- 既に外部 DNS を使っているなら、手動で CNAME / ALIAS を張ってもよい

## 使い方の流れ

このディレクトリには、Terraform / Docker / ECR / ECS の操作をまとめた `Makefile` を用意しています。
手打ちコマンドを減らしたい場合は、まず `make help` を見るのがおすすめです。

### 1. インフラの初回作成

最初は `desired_count = 0` のまま apply するのがおすすめです。
これで **ECR や ALB などの土台を先に作りつつ、Keycloak は AWS 上で先に起動** できます。

- `dev.tfvars` または `prod.tfvars` のプレースホルダーを実値へ置き換える
- `make bootstrap ENV=dev`

Terraform を素直に打ちたい場合は、従来どおり以下でも構いません。

- `terraform init`
- `terraform plan -var-file=dev.tfvars`
- `terraform apply -var-file=dev.tfvars -var="desired_count=0"`

apply 後は、まず以下を確認します。

- `terraform output keycloak_admin_console_url`
- `terraform output keycloak_realm_url`

Admin Console にログインしたら、realm / clients / scopes を作成してから MCP アプリ側を有効化すると流れがきれいです。

### 2. Docker イメージをビルドして ECR に push

Terraform apply 後、`ecr_repository_url` 出力に対して push します。

Makefile を使う場合はこれだけです。

- `make docker-push ENV=dev`

内部では、以下を自動で行います。

- ECR へ Docker ログイン
- `docker/Dockerfile` からイメージ build
- Terraform output から ECR URL を取得
- `IMAGE_TAG` を付けて ECR に push

`IMAGE_TAG` は未指定時に Git の short SHA、Git 管理外ならタイムスタンプを使います。
このプロジェクトの ECR は **tag immutable** なので、毎回別タグを使うほうが再デプロイで詰まりにくいです。

### 3. タスク数を増やして再 apply

`desired_count` を `1`（本番なら `2` 以上）へ変更して再 apply します。

Makefile を使う場合:

- `make deploy ENV=dev DESIRED_COUNT=1`

build / push / deploy を一気にやるなら:

- `make release ENV=dev DESIRED_COUNT=1`

`IMAGE_TAG` を明示したい場合の例:

- `make release ENV=dev IMAGE_TAG=v20260307-1 DESIRED_COUNT=1`

Makefile には他にも以下があります。

- `make plan ENV=dev`
- `make status ENV=dev`
- `make urls ENV=dev`
- `make logs ENV=dev SINCE=1h`
- `make destroy ENV=dev`

## 補足

- `container_image` を直接指定すれば、他のレジストリのイメージも利用可能
- `enable_server_oauth = true` を前提に、Claude Desktop 等の MCP クライアント向け認証を提供する
- Python 側は JWT の自前検証ではなく、Keycloak の introspection endpoint による検証を採用している
- Keycloak 本番運用では HTTPS・公開ホスト名固定・reverse proxy 配下の運用を推奨
- Keycloak は `/keycloak` 配下に置いているため、発行される issuer / discovery URL もそのプレフィックス付きになる

## コスト注意

- **Keycloak ECS**: Fargate の常時稼働コストがかかる
- **Keycloak RDS**: DB インスタンスの常時課金がかかる
- **NAT Gateway**: 常時課金があるため、学習後は `terraform destroy` を忘れずに
- **ALB**: 時間課金 + 処理量課金
- **Fargate**: タスク数と CPU / メモリに応じて課金
- **CloudWatch Logs**: ログ保存量に応じて課金
