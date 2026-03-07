# ECS Fargate + FastMCP + ALB(OIDC) サンプル

`python/main.py` にある FastMCP サーバーを **変更せず** に Docker 化し、ECR / ECS Fargate / ALB / ACM / OIDC 認証で公開する学習用サンプルです。

## 何を作るか

```text
クライアント
  ↓ HTTPS
ALB
  ├─ /mcp    → OIDC認証 → ECS Fargate タスクへ転送
  └─ /health → 認証なしで ECS Fargate タスクへ転送
        ↓
FastMCP (streamable HTTP)
        ↓
CloudWatch Logs / Container Insights
```

## 設計のポイント

- **アプリ無改造の認証**
  - ALB の `authenticate-oidc` を使う
  - `python/main.py` 側にログイン処理や JWT 検証を入れなくてよい
- **HTTPS 終端**
  - ALB に ACM 証明書を設定
  - HTTP(80) は HTTPS(443) へリダイレクト
- **ヘルスチェック**
  - FastMCP の `/mcp` は MCP クライアント向けで、ALB の単純な GET ヘルスチェックには向かない
  - そこで Docker ラッパー (`docker/server.py`) が `/health` を返す
  - `main.py` は変えずに ALB / ECS のヘルスチェックを安定させる
- **スケールしやすさ**
  - `stateless_http=true` で FastMCP を起動
  - ALB 配下で複数タスクへ広げやすい構成にしている

## ファイル構成

| ファイル | 内容 |
|---|---|
| `provider.tf` | AWS プロバイダ設定 |
| `variables.tf` | 変数定義（ACM / OIDC / Cognito / Route53 など外部前提を含む） |
| `vpc.tf` | VPC / Subnet / IGW / NAT Gateway / Route Table |
| `security_groups.tf` | ALB 用 / ECS 用セキュリティグループ |
| `ecr.tf` | ECR リポジトリ |
| `iam.tf` | ECS タスク実行ロール |
| `cognito.tf` | Cognito User Pool / Domain / Client / OIDC 解決用 locals |
| `alb.tf` | ALB / Target Group / Listener / Listener Rule / 任意の Route53 レコード |
| `ecs.tf` | ECS Cluster / Task Definition / Service / CloudWatch Logs |
| `outputs.tf` | 主要な出力値 |
| `docker/Dockerfile` | FastMCP コンテナ化 |
| `docker/server.py` | `/health` を持つ薄い HTTP ラッパー |
| `docker/requirements.txt` | Docker 用 Python 依存 |
| `dev.tfvars` | 開発用変数例 |
| `prod.tfvars` | 本番用変数例 |

## apply 前に必要な外部前提

このディレクトリだけでは完結しないものは、すべて変数化しています。

### 1. ACM 証明書

- 変数: `acm_certificate_arn`
- ALB と **同じリージョン** の ACM 証明書が必要
- 独自ドメインで使うなら、証明書の CN/SAN と `app_domain_name` を一致させる

### 2. OIDC 認証プロバイダ

OIDC プロバイダには **Cognito（Terraform 管理）** と **外部 IdP（手動設定）** の 2 つの方式がある。

#### 方式 A: Cognito を使う（推奨）

`use_cognito = true` にすると、Terraform が Cognito User Pool / Domain / Client を自動作成し、
ALB の OIDC エンドポイントも自動で設定される。手動で OIDC の URL を調べる必要がない。

- 変数:
  - `use_cognito = true`
  - `cognito_domain_prefix` — AWS 全体でグローバルに一意な文字列
- apply 後に Cognito ユーザーを作成する:

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <cognito_user_pool_id 出力値> \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password 'TempPass1!'
```

初回アクセス時に Hosted UI でパスワード変更が求められる。

#### 方式 B: 外部 IdP を使う（Google, Auth0 等）

`use_cognito = false` にして、以下の変数で外部 IdP のエンドポイントを手動指定する。

- 変数:
  - `enable_oidc_auth`
  - `oidc_issuer`
  - `oidc_authorization_endpoint`
  - `oidc_token_endpoint`
  - `oidc_user_info_endpoint`
  - `oidc_client_id`
  - `oidc_client_secret`
- OIDC 側に登録するコールバック URL は Terraform 出力の `oidc_redirect_uri`
  - 例: `https://mcp.example.com/oauth2/idpresponse`

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
これで **ECR や ALB などの土台だけ先に作成** できます。

- `dev.tfvars` または `prod.tfvars` のプレースホルダーを実値へ置き換える
- `make bootstrap ENV=dev`

Terraform を素直に打ちたい場合は、従来どおり以下でも構いません。

- `terraform init`
- `terraform plan -var-file=dev.tfvars`
- `terraform apply -var-file=dev.tfvars -var="desired_count=0"`

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
- 学習を進める途中で OIDC がまだ無ければ、一時的に `enable_oidc_auth = false` で ALB のパス転送だけ先に確認できる
- ただし本来の要件は **ALB 認証あり** なので、最終的には OIDC を有効にする前提
- `cognito_domain_prefix` は AWS 全体で一意でなければならず、既に使われている場合は別の値に変更する

## コスト注意

- **Cognito User Pool**: 月間アクティブユーザー (MAU) 50,000 人まで無料枠あり。学習用途ではほぼ無料
- **NAT Gateway**: 常時課金があるため、学習後は `terraform destroy` を忘れずに
- **ALB**: 時間課金 + 処理量課金
- **Fargate**: タスク数と CPU / メモリに応じて課金
- **CloudWatch Logs**: ログ保存量に応じて課金
