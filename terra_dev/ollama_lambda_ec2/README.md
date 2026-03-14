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
- Ansible
- Session Manager Plugin
- `amazon.aws` Ansible collection
- 既存の **default VPC** と **default subnets**

> 補足: `amazon.aws.aws_ssm` 接続プラグインのバージョンによっては、一時ファイル転送用の S3 バケット設定が必要です。その場合は `ANSIBLE_AWS_SSM_BUCKET` を環境変数で渡してください。

## Terraform の使い方

### 1. tfvars を調整する

`dev.tfvars` または `prod.tfvars` の `shared_api_secret` を必ず置き換えてください。

### 2. 初期化

```bash
cd terra_dev/ollama_lambda_ec2
terraform init
```

### 3. プラン確認

```bash
terraform plan -var-file="dev.tfvars"
```

### 4. 適用

```bash
terraform apply -var-file="dev.tfvars"
```

### 5. 出力確認

```bash
terraform output generate_url
terraform output ec2_instance_id
terraform output shared_api_secret_name
```

## Ansible の使い方

Terraform apply 後、EC2 が起動して Session Manager に見える状態になったら Ollama を導入します。

### 1. Collection を入れる

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 2. 動的インベントリ確認

```bash
ansible-inventory -i inventory.aws_ec2.yml --graph
```

### 3. Playbook 実行

```bash
ansible-playbook -i inventory.aws_ec2.yml playbook.yml --limit tag_Environment_dev
```

`prod` の場合は `--limit tag_Environment_prod` に変えてください。

## API 呼び出し例

```bash
curl -X POST "$(terraform output -raw generate_url)" \
  -H "content-type: application/json" \
  -H "x-api-key: CHANGE-ME-DEV-SHARED-SECRET" \
  -d '{"prompt":"こんにちは、自己紹介して","model":"qwen2.5:0.5b"}'
```

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
- Ansible 接続に失敗する: Session Manager Plugin、`amazon.aws` collection、EC2 の SSM Managed Instance 登録状態を確認してください。
- EC2 は public subnet にいますが **inbound を開けていない** ので、ブラウザや SSH では直接触れません。これは仕様です。ちょっとストイックですが安全寄りです。

## 削除

```bash
terraform destroy -var-file="dev.tfvars"
```

Secrets Manager secret は recovery window を持つため、削除反映に時間がかかる場合があります。
