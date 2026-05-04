# Big Picture - Ollama on EC2 + Async Lambda API

## 確定した設計判断

| 項目 | 確定内容 | 補足 |
|------|----------|------|
| 詳細設計ファイル名 | `DETAIL.md` | 既存プロジェクトに合わせる |
| 構成管理の責務分離 | **Terraform = AWS リソース作成** / **Ansible Playbook = EC2 内部設定と更新** | EC2 の中身は Playbook で管理する |
| Playbook の適用範囲 | Ollama インストール、systemd 設定、モデル pull、推論設定、更新作業 | 初回構築だけでなく更新手順も Playbook 前提 |
| API の公開方式 | **API Gateway → API Lambda → SQS FIFO → Worker Lambda → EC2(Ollama)** | EC2 を直接 API 公開しない |
| API 応答方式 | `POST /generate` は `202 Accepted`、結果取得は `GET /requests/{request_id}` | 重い推論処理はキューに逃がす |
| キュー制御 | **SQS FIFO + batch size 1 + Worker Lambda reserved concurrency = 1** | Ollama 推論を常に 1 件ずつ直列実行する |
| 状態保存 | **DynamoDB** に `QUEUED` / `PROCESSING` / `SUCCEEDED` / `FAILED` を保存 | 完了結果や失敗詳細も保持する |
| EC2 と Lambda の通信 | **同一 VPC 内の private IP 通信** | 実際に Ollama を呼ぶのは Worker Lambda |
| EC2 への運用アクセス | **Session Manager 優先** | SSH は初期構成では作らない |
| API 認証 | **共有シークレット方式** | API Lambda が `x-api-key` を検証する |
| 初期モデル | `qwen2.5:0.5b` | リクエストで省略された場合の既定値 |

## 採用する具体設定

### AWS / Terraform 基本設定

- リージョン: `ap-northeast-1`
- プロジェクト名: `ollama-lambda-ec2`
- 環境名: `dev` / `prod`
- タグ方針:
  - `Project = ollama-lambda-ec2`
  - `ManagedBy = Terraform`
  - `Environment = dev | prod`

### ネットワーク設定

- **既存の Default VPC を利用する**
  - 学習コストと Terraform 記述量を抑えるため、専用 VPC は新設しない
- EC2 は Default VPC の default subnet に配置する
- API Lambda / Worker Lambda も同じ Default VPC の default subnet 群に VPC 接続する
- Lambda から EC2 へは **private IP** で接続する
- EC2 の Ollama 待受ポートは `11434`
- NAT Gateway は使わず、Lambda からの AWS サービス到達性は次で確保する
  - Secrets Manager: **Interface VPC Endpoint**
  - SQS: **Interface VPC Endpoint**
  - DynamoDB: **Gateway VPC Endpoint**

### セキュリティグループ設定

#### EC2 用 Security Group

- Inbound
  - `11434/tcp`: **Lambda 用 Security Group からのみ許可**
- Outbound
  - `443/tcp`: パッケージ取得、Ollama 本体 / モデル取得、SSM 関連通信用
  - `80/tcp`: 一部パッケージ取得の初期通信向け
  - `53/tcp`, `53/udp`: VPC DNS Resolver 向け

#### Lambda 用 Security Group

- Outbound
  - `11434/tcp`: EC2 用 Security Group 宛て
  - `443/tcp`: Secrets Manager Interface Endpoint 宛て
  - `443/tcp`: SQS Interface Endpoint 宛て
  - `443/tcp`: DynamoDB Prefix List 宛て
  - `53/tcp`, `53/udp`: VPC DNS Resolver 宛て

#### Interface Endpoint 用 Security Group

- Inbound
  - `443/tcp`: Lambda 用 Security Group からのみ許可

> 補足: API Lambda と Worker Lambda は同じ Lambda Security Group を共有します。実装上、EC2 への Ollama 呼び出しは Worker Lambda だけが行いますが、ネットワーク許可そのものは Lambda SG 単位です。

### 非同期リクエストパイプライン

1. クライアントが `POST /generate` を呼び出す
2. API Lambda が `x-api-key` と JSON ボディを検証する
3. API Lambda が DynamoDB に初期状態 `QUEUED` のレコードを作成する
4. API Lambda が SQS FIFO にメッセージを投入する
   - `MessageGroupId`: 固定値
   - `MessageDeduplicationId`: `request_id`
5. API Lambda は `202 Accepted` と `request_id` / `status_url` を返す
6. SQS Event Source Mapping が `batch_size = 1` で Worker Lambda を起動する
7. Worker Lambda が DynamoDB を `PROCESSING` に更新し、EC2 上の Ollama を private IP で呼ぶ
8. Worker Lambda が結果に応じて DynamoDB を更新する
   - 成功: `SUCCEEDED` + `result_json`
   - 失敗: `FAILED` + `error_message` / `error_type` / `error_details_json`
9. クライアントは `GET /requests/{request_id}` をポーリングして状態を見る
10. 再試行上限を超えたメッセージは DLQ に送られる

### DynamoDB に保存する主な項目

- `request_id`: パーティションキー
- `status`: `QUEUED` / `PROCESSING` / `SUCCEEDED` / `FAILED`
- `model`: リクエスト時に確定したモデル名
- `created_at`, `updated_at`, `completed_at`: ISO 8601 形式の時刻
- `result_json`: 成功時の Ollama 応答 JSON
- `error_message`, `error_type`, `error_details_json`: 失敗時の情報
- `expires_at`: TTL 用 Unix epoch 秒

### EC2 設定

- OS: **Amazon Linux 2023**
- アーキテクチャ: `x86_64`
- インスタンスタイプ:
  - `dev`: `t3.medium`
  - `prod`: `t3.large`
- ルートボリューム:
  - タイプ: `gp3`
  - サイズ: `30GB`
  - 暗号化: 有効
- パブリック公開:
  - Public IP は付くが、外部向け Inbound は開けない
  - `22`, `80`, `443`, `11434` はインターネットに公開しない

### Ollama 設定

- インストール方法: Ansible Playbook で導入
- サービス管理: `systemd`
- 待受アドレス: `0.0.0.0:11434`
  - ただし Security Group で Lambda からの通信だけを許可する
- 初回起動時に Playbook で以下を実施する
  - Ollama インストール
  - サービス有効化・起動
  - `qwen2.5:0.5b` の pull
  - 動作確認コマンド実行
- 将来のモデル差し替えに備えて、モデル名は Ansible 変数化する

### Lambda 設定

#### API Lambda

- ランタイム: `Python 3.12`
- アーキテクチャ: `x86_64`
- 配置: Default VPC の default subnet 群
- 主な役割:
  - `x-api-key` 検証
  - `POST /generate` の入力検証
  - DynamoDB への初期レコード作成
  - SQS FIFO への投入
  - `GET /requests/{request_id}` の状態参照
- 主な環境変数:
  - `DEFAULT_MODEL`
  - `REQUESTS_TABLE_NAME`
  - `REQUEST_QUEUE_URL`
  - `REQUEST_QUEUE_GROUP_ID`
  - `REQUEST_STATUS_TTL_HOURS`
  - `SHARED_API_SECRET_ARN`
  - `SHARED_API_SECRET_NAME`

#### Worker Lambda

- ランタイム: `Python 3.12`
- アーキテクチャ: `x86_64`
- 配置: Default VPC の default subnet 群
- `reserved_concurrent_executions = 1`
- Event Source Mapping: SQS FIFO / `batch_size = 1`
- 主な役割:
  - SQS メッセージ 1 件処理
  - DynamoDB の `PROCESSING` / `SUCCEEDED` / `FAILED` 更新
  - EC2 上の Ollama 呼び出し
- 主な環境変数:
  - `DEFAULT_MODEL`
  - `OLLAMA_BASE_URL=http://<ec2_private_ip>:11434`
  - `OLLAMA_REQUEST_TIMEOUT_SECONDS`
  - `REQUESTS_TABLE_NAME`

### API Gateway 設定

- API 種別: **HTTP API**
- Lambda Proxy Integration: payload format version `2.0`
- 公開ルート:
  - `POST /generate`
  - `GET /requests/{request_id}`
- 認証:
  - 両ルートとも `x-api-key` を送る
  - API Lambda が検証し、不一致なら `403` を返す
- streaming は使わない
  - まずは通常レスポンスのみ対応する

### Secrets / 認証情報

- 共有シークレットは **AWS Secrets Manager** で管理する
- Terraform で Secret と Secret Version を作成する
- API Lambda には平文を埋め込まず、実行時に Secret を取得してキャッシュする
- Worker Lambda や EC2 側には API 認証用シークレットを置かない
- 注意点:
  - `aws_secretsmanager_secret_version` により **Terraform state に平文が残る**

### IAM 設定

#### EC2 ロール

- `AmazonSSMManagedInstanceCore` を付与
- 初期版では S3 / Secrets Manager への追加権限は付与しない

#### API Lambda ロール

- CloudWatch Logs 書き込み権限
- VPC 実行権限
- Secrets Manager 読み取り権限
- DynamoDB `GetItem` / `PutItem`
- SQS `SendMessage`

#### Worker Lambda ロール

- CloudWatch Logs 書き込み権限
- VPC 実行権限
- DynamoDB `GetItem` / `UpdateItem`

## Playbook 運用方針

### Playbook 実行方式

- ローカルマシンから Ansible を実行する
- 接続方式は **AWS Systems Manager Session Manager 経由** を前提にする
- Ansible の接続プラグインは `amazon.aws.aws_ssm` を採用する
- ローカル前提ツール:
  - `aws cli`
  - `ansible`
  - `amazon.aws` Collection

### Playbook で管理する項目

- Ollama パッケージ導入
- systemd ユニット配置 / 再読み込み
- `OLLAMA_HOST` などの環境設定
- モデル pull の実行
- 動作確認コマンド
- バージョン更新時の再適用

### Terraform でやらないこと

- `user_data.sh` に Ollama の本設定を大量に書かない
- モデル pull を Terraform の副作用にしない
- EC2 内のアプリ更新を Terraform `apply` に背負わせない

### 初期ブートストラップの考え方

- `user_data.sh` は最小限にする
- 役割は以下に限定する
  - SSM Agent の利用準備確認
  - Python / 基本パッケージの準備
  - Ansible 実行に必要な最低限の依存を整える
- 実際の Ollama 導入は Playbook 実行後に行う

## ディレクトリ構成の確定案

```text
ollama_lambda_ec2/
├── PLAN.md
├── DETAIL.md
├── README.md
├── provider.tf
├── variables.tf
├── data.tf
├── network.tf
├── ec2.tf
├── lambda.tf
├── async.tf
├── api_gateway.tf
├── iam.tf
├── outputs.tf
├── dev.tfvars
├── prod.tfvars
├── user_data.sh
├── src/
│   ├── common.py
│   ├── api_lambda.py
│   └── worker_lambda.py
└── ansible/
    ├── ansible.cfg
    ├── inventory.aws_ec2.yml
    ├── playbook.yml
    ├── requirements.yml
    ├── group_vars/
    │   └── all.yml
    └── roles/
        └── ollama_server/
            ├── tasks/main.yml
            ├── templates/ollama.service.j2
            └── defaults/main.yml
```

## API リクエスト / レスポンス仕様

### `POST /generate` リクエスト

```json
{
  "prompt": "こんにちは",
  "model": "qwen2.5:0.5b"
}
```

### 共通ヘッダー

- `Content-Type: application/json`
- `x-api-key: <shared-secret>`

### `POST /generate` 正常レスポンス (`202 Accepted`)

```json
{
  "request_id": "<api-lambda-request-id>",
  "status": "QUEUED",
  "status_url": "https://.../requests/<api-lambda-request-id>"
}
```

### `GET /requests/{request_id}` 成功レスポンス例

```json
{
  "request_id": "<api-lambda-request-id>",
  "status": "SUCCEEDED",
  "model": "qwen2.5:0.5b",
  "result": {
    "model": "qwen2.5:0.5b",
    "response": "...",
    "done": true
  }
}
```

### `GET /requests/{request_id}` 処理中レスポンス例

```json
{
  "request_id": "<api-lambda-request-id>",
  "status": "PROCESSING"
}
```

### `GET /requests/{request_id}` 失敗レスポンス例

```json
{
  "request_id": "<api-lambda-request-id>",
  "status": "FAILED",
  "error": {
    "message": "Request processing failed.",
    "type": "OllamaInvocationError"
  }
}
```

### エラーレスポンス方針

- 認証失敗: `403`
- 入力不正: `400`
- 存在しない `request_id`: `404`
- API Lambda 内部エラー: `500`
- Worker 側の接続失敗や推論失敗: HTTP エラーとして即返さず、DynamoDB 上の `FAILED` として返す

## 運用ルール

- インフラ変更: Terraform
- EC2 内設定変更: Ansible Playbook
- モデル差し替え: Ansible 変数を更新して Playbook 再実行
- Lambda コード変更: Terraform 経由で再デプロイ
- SSH 鍵は初期版では作らない
- EC2 への手動ログインは Session Manager のみを基本とする
- キュー詰まりや失敗調査は CloudWatch Logs / DynamoDB / DLQ を合わせて確認する

## 今回あえて採用しないもの

- Application Load Balancer
- Auto Scaling
- 専用 VPC の新設
- NAT Gateway
- API Gateway Authorizer
- WebSocket / Streaming 応答
- GPU インスタンス

これらは、まず CPU ベースで `qwen2.5:0.5b` を安定稼働させた後に必要に応じて追加する。
