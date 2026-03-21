# ollama_lambda_ec2

Default VPC を使って **API Gateway → Lambda → EC2(Ollama)** の流れを学ぶための、Terraform + Lambda + Ansible のスタンドアロン教材プロジェクトです。Terraform は AWS リソース作成に集中し、EC2 内部の Ollama セットアップは Ansible に分離しています。

## このプロジェクトで作るもの

- HTTP API: `POST /generate`
- Lambda: `x-api-key` を検証し、Secrets Manager から共有シークレットを取得して EC2 上の Ollama へ転送
- EC2: Amazon Linux 2023 + Session Manager 対応 + Ollama 実行ホスト
- Secrets Manager: 共有 API シークレットを保存
- VPC Endpoint: NAT なしでも Lambda が Secrets Manager を引けるようにする Interface Endpoint
- CloudWatch Logs: Lambda ログと API Gateway アクセスログを明示的に作成

## アーキテクチャ

```text
Client
  -> HTTPS
API Gateway HTTP API
  -> Lambda proxy integration (payload v2.0)
Lambda (in default VPC)
  -> private IP HTTP
EC2 Ollama server (in default public subnet, inbound closed from internet)
```

## 設計上のポイント

- **Default VPC / default public subnet を利用**: 学習しやすさ優先。存在しない場合は Terraform がそのまま失敗します。
- **NAT Gateway は使わない**: 代わりに Lambda 用に **Secrets Manager Interface VPC Endpoint** を作成します。
- **EC2 は public IP あり**: 初期ブートストラップ、パッケージ取得、Session Manager、Ollama / model ダウンロードのためです。
- **ただし inbound は閉じる**: インターネットから EC2 へ SSH / HTTP / HTTPS / 11434 を開けません。
- **SG-to-SG 制御**: `11434/tcp` は Lambda SG から EC2 SG へのみ許可します。
- **IMDSv2 強制**: EC2 で `http_tokens = required` を明示しています。
- **Lambda には秘密値を渡さない**: 環境変数には secret ARN / name だけを入れ、値は実行時に Secrets Manager から取得します。
- **HTTP API の実効ボディ上限は 6 MB**: HTTP API 自体よりも、Lambda 同期呼び出しのペイロード制限の方が厳しいためです。
- **Terraform state に秘密値が入る**: `aws_secretsmanager_secret_version` で平文を管理するため、state の保護は必須です。

## ディレクトリ構成

- `provider.tf` / `variables.tf` / `data.tf`: 共通設定とデータソース
- `network.tf`: Security Group と Secrets Manager VPC Endpoint
- `ec2.tf`: Ollama ホスト用 EC2
- `lambda.tf`: Secret、Lambda、Lambda Log Group
- `api_gateway.tf`: HTTP API、`$default` stage、アクセスログ
- `iam.tf`: EC2 / Lambda ロール
- `src/lambda_function.py`: 入力検証・認証・Ollama 転送
- `ansible/`: Session Manager 経由で Ollama を導入するプレイブック
- `user_data.sh`: Python や SSM 周りの最小ブートストラップのみ

## 前提条件

- Terraform `>= 1.0`
- AWS CLI（認証済み）
- Docker
- 既存の **default VPC** と **default subnets**

> 補足: Ansible 実行は既定で Docker コンテナ内のランナーに寄せています。コンテナイメージには `ansible-core`、`amazon.aws` collection、AWS CLI、Session Manager Plugin を同梱します。どうしてもローカル実行したい場合だけ `ANSIBLE_RUNNER=local` を指定してください。

## Makefile でまとめて操作する

プロジェクト直下に `Makefile` を用意してあるので、Terraform / Ansible / curl テストを `make` 経由でまとめて実行できます。

まずは一覧を確認します。

```bash
make help
```

よく使うターゲット:

- `make plan`: `dev.tfvars` で Terraform plan
- `make apply`: `dev.tfvars` で Terraform apply
- `make ansible-image`: Docker 版 Ansible ランナーを build
- `make ansible`: `dev` 環境の EC2 に Ollama を導入
- `make ansible-shell`: Docker 版 Ansible ランナーに入って手で確認
- `make test`: API Gateway → Lambda → EC2(Ollama) の疎通確認
- `make up`: `apply` → `ansible` → `test` をまとめて実行
- `make destroy`: `dev.tfvars` で Terraform destroy

`prod` を使いたい場合は `ENV=prod` を付けてください。

```bash
make plan ENV=prod
make apply ENV=prod
make ansible ENV=prod
make test ENV=prod
```

API テスト時のプロンプトやモデルは上書きできます。

```bash
make test PROMPT="俳句を1つ作って" MODEL="qwen2.5:0.5b"
```

## Terraform の使い方

### 1. tfvars を調整する

`dev.tfvars` または `prod.tfvars` の `shared_api_secret` を必ず置き換えてください。

### 2. 初期化

```bash
make init
```

### 3. プラン確認

```bash
make plan
```

### 4. 適用

```bash
make apply
```

### 5. 出力確認

```bash
make output
```

## Ansible の使い方

Terraform apply 後、EC2 が起動して Session Manager に見える状態になったら Ollama を導入します。

### 1. Docker ランナーを準備する

```bash
make ansible-install
```

これは既定では `docker/ansible-runner/Dockerfile` から Ansible ランナーイメージを build します。ホスト側で必要なのは Docker と AWS 認証情報だけです。

### 2. 動的インベントリ確認

```bash
make ansible-inventory
```

このインベントリでは `tags.Environment` を keyed group にしているため、環境ごとのグループ名は `tag_dev` / `tag_prod` になります。

### 3. Playbook 実行

```bash
make ansible
```

`prod` の場合は `make ansible ENV=prod` を使ってください。

`make ansible` は `amazon.aws.aws_ssm` 接続プラグイン用の一時 S3 バケットを自動で決定し、存在しなければ作成してからプレイブックを Docker コンテナ内で実行します。既存のバケットを使いたい場合は `ANSIBLE_AWS_SSM_BUCKET` を環境変数で上書きできます。

ローカルにインストール済みの Ansible を使いたい場合は、次のように明示してください。

```bash
make ansible ANSIBLE_RUNNER=local
```

## API 呼び出し例

```bash
make test
```

`make test` は Terraform output から `generate_url` と `shared_api_secret_name` を取得し、Secrets Manager からシークレット値を引いて `curl` を実行します。つまり、毎回 `x-api-key` を手で貼らなくて大丈夫です。ちょっと賢いです。

期待レスポンス例:

```json
{
  "model": "qwen2.5:0.5b",
  "response": "...",
  "done": true
}
```

## 運用メモ

- EC2 への管理アクセスは **Session Manager のみ** を想定しています。
- Lambda は Secrets Manager の値を実行環境ごとにキャッシュするため、毎回取り直す実装ではありません。
- Lambda は接続エラーを `502`、Ollama 応答タイムアウトを `504`、入力不正を `400`、認証失敗を `403` にマッピングします。
- この構成では Ollama の streaming は使わず、通常レスポンスだけを返します。
- 初回モデル pull は時間がかかるので、Ansible 実行直後の検証は少し待つと穏やかです。

## トラブルシュートのヒント

- Lambda が secret を読めない: Interface VPC Endpoint、Lambda SG、DNS egress を確認してください。
- Lambda から EC2 に繋がらない: EC2 private IP、`11434/tcp` の SG-to-SG ルール、Ollama service 状態を確認してください。
- Ansible 接続に失敗する: Docker ランナーイメージの build 成否、EC2 の SSM Managed Instance 登録状態、そして SSM 用一時 S3 バケットにアクセスできることを確認してください。`make ansible-shell` でコンテナに入って切り分けると速いです。
- EC2 は public subnet にいますが **inbound を開けていない** ので、ブラウザや SSH では直接触れません。これは仕様です。ちょっとストイックですが安全寄りです。

## 削除

```bash
make destroy
```

Secrets Manager secret は recovery window を持つため、削除反映に時間がかかる場合があります。
