# Big Picture - Ollama on EC2 + Lambda API

## このファイルの役割

このファイルは、`PLAN.md` に書いた実装方針のうち、**実際にどの設定で作るかを確定した内容だけ**をまとめる。
概要説明や学習ポイントは `PLAN.md` に任せ、ここでは「何をどう設定するか」を明示する。

## 確定した設計判断

| 項目 | 確定内容 | 補足 |
|------|----------|------|
| 詳細設計ファイル名 | `DETAIL.md` | 既存プロジェクトに合わせる |
| 構成管理の責務分離 | **Terraform = AWSリソース作成** / **Ansible Playbook = EC2内部設定と更新** | EC2 の中身は Playbook で管理する |
| Playbook の適用範囲 | Ollama インストール、systemd 設定、モデル pull、推論設定、更新作業 | 初回構築だけでなく更新手順も Playbook 前提 |
| API の公開方式 | API Gateway → Lambda → EC2(Ollama) | EC2 を直接 API 公開しない |
| EC2 と Lambda の通信 | **同一 VPC 内の private IP 通信** | Ollama は private IP 宛にのみ使う |
| EC2 への運用アクセス | **Session Manager 優先** | SSH は初期構成では作らない |
| API 認証 | **共有シークレット方式** | Lambda でヘッダーを検証する |
| 初期モデル | `qwen2.5:0.5b` | Lambda からの指定がなければこのモデルを使う |

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
  - 学習コストと Terraform 記述量を抑えるため、初期版では専用 VPC を新設しない
- EC2 は Default VPC のサブネットに配置する
- Lambda も同一 VPC のサブネットに配置する
- Lambda から EC2 へは **private IP** で接続する
- EC2 の Ollama 待受ポートは `11434`

### セキュリティグループ設定

#### EC2 用 Security Group

- Inbound
  - `11434/tcp` : **Lambda 用 Security Group からのみ許可**
- Outbound
  - `443/tcp` : インターネット向け許可（Ollama ダウンロード、モデル取得、AWS API 呼び出し用）
  - `80/tcp` : 初期セットアップ時のパッケージ取得用に許可
  - その他はデフォルト許可のまま始め、必要に応じて絞る

#### Lambda 用 Security Group

- Outbound
  - `11434/tcp` : EC2 用 Security Group 宛て通信を許可

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
  - EC2 に対する公開 HTTP/HTTPS は作らない
  - セキュリティグループで `22`, `80`, `443`, `11434` の外部公開はしない

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

- ランタイム: `Python 3.12`
- アーキテクチャ: `x86_64`
- タイムアウト: `29秒`
  - API Gateway の上限を意識して 29 秒に固定
- メモリサイズ: `1024MB`
- 配置: EC2 と同一 VPC 内
- 環境変数:
  - `OLLAMA_BASE_URL=http://<ec2_private_ip>:11434`
  - `DEFAULT_MODEL=qwen2.5:0.5b`
  - `SHARED_API_SECRET=<Secrets Manager 参照 or Terraform 変数>`
- Lambda の役割:
  - リクエストヘッダーのシークレット検証
  - リクエスト JSON の検証
  - Ollama API への転送
  - エラー整形

### API Gateway 設定

- API 種別: **HTTP API**
- エンドポイント:
  - `POST /generate`
- リクエスト例:
  - `prompt`: 必須
  - `model`: 任意、省略時は `qwen2.5:0.5b`
- 初期版では **streaming は無効**
  - Lambda 経由の実装を簡単に保つため、まずは通常レスポンスのみ対応
- 認証:
  - `x-api-key` のような共有シークレット用ヘッダーをクライアントが送信
  - Lambda 側で検証し、不一致なら `403` を返す

### Secrets / 認証情報

- 共有シークレットは **AWS Secrets Manager で管理する前提** とする
- Terraform でシークレットリソースを作成し、値自体は変数経由で投入する
- Lambda には平文固定値をハードコードしない
- EC2 側には API 認証用シークレットを置かない
  - API 認証の責務は Lambda 側に限定する

### IAM 設定

#### EC2 ロール

- `AmazonSSMManagedInstanceCore` を付与
- 初期版では S3 / Secrets Manager への追加権限は付与しない
  - Ollama インストールとモデル取得はインターネット経由で行う

#### Lambda ロール

- CloudWatch Logs 書き込み権限
- Secrets Manager 読み取り権限（共有シークレット取得用）
- ENI 作成に必要な VPC 実行権限

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
├── api_gateway.tf
├── iam.tf
├── outputs.tf
├── dev.tfvars
├── prod.tfvars
├── user_data.sh
├── src/
│   └── lambda_function.py
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

## API リクエスト / レスポンスの初期仕様

### リクエスト

```json
{
  "prompt": "こんにちは",
  "model": "qwen2.5:0.5b"
}
```

### ヘッダー

- `Content-Type: application/json`
- `x-api-key: <shared-secret>`

### 正常レスポンス

```json
{
  "model": "qwen2.5:0.5b",
  "response": "...",
  "done": true
}
```

### エラーレスポンス方針

- 認証失敗: `403`
- 入力不正: `400`
- EC2 接続失敗: `502`
- Ollama 応答タイムアウト: `504`
- Lambda 内部エラー: `500`

## 運用ルール

- インフラ変更: Terraform
- EC2 内設定変更: Ansible Playbook
- モデル差し替え: Ansible 変数を更新して Playbook 再実行
- Lambda コード変更: Terraform 経由で再デプロイ
- SSH 鍵は初期版では作らない
- EC2 への手動ログインは Session Manager のみを基本とする

## 今回あえて採用しないもの

- Application Load Balancer
- Auto Scaling
- 専用 VPC の新設
- NAT Gateway
- API Gateway Authorizer
- WebSocket / Streaming 応答
- GPU インスタンス

これらは、まず CPU ベースで `qwen2.5:0.5b` を安定稼働させた後に必要に応じて追加する。
