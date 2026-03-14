# Ollama + EC2 + Lambda API - 実装プラン

## 概要

EC2 上で Ollama を起動し、初期モデルとして `qwen2.5:0.5b` をロードした推論 API を構築する。
外部からのリクエストは Lambda を経由して受け付け、Lambda から EC2 上の Ollama API を呼び出して応答を返す。
Terraform では、推論サーバー・中継 API・IAM・ネットワーク・運用に必要な周辺リソースを段階的に定義する。

## アーキテクチャ

```text
クライアント
  ↓ HTTPS リクエスト
API Gateway
  ↓ Lambda Invoke
Lambda 関数
  ↓ HTTP リクエスト（VPC 内 or 制限付き通信）
EC2 上の Ollama サーバー
  ↓ モデル推論
qwen2.5:0.5b
```

## 技術スタック

- **EC2**: Ollama 実行用の推論サーバー
- **Ollama**: ローカル LLM 実行基盤
- **qwen2.5:0.5b**: 初期デプロイ対象の軽量モデル
- **Lambda (Python想定)**: API リクエストの受け口と EC2 への中継処理
- **API Gateway**: 外部公開用の HTTPS API
- **IAM**: Lambda / EC2 に必要な最小権限の設定
- **Security Group**: API 通信経路の制限
- **CloudWatch Logs**: Lambda と EC2 のログ監視

## 作成物

- `POST /generate` でプロンプトを受け取り、LLM の応答を返す API
- EC2 起動時に Ollama をセットアップし、`qwen2.5:0.5b` を pull して待ち受ける構成
- Lambda から EC2 上の Ollama API に対して推論リクエストを送る中継処理
- 将来的にモデル名や生成パラメータを切り替えやすい Terraform / Lambda 構成

## 構成ファイル（予定）

```text
ollama_lambda_ec2/
├── PLAN.md              # 本ファイル（実装プラン）
├── README.md            # プロジェクト説明
├── provider.tf          # AWS プロバイダ設定
├── variables.tf         # 変数定義
├── network.tf           # VPC / Subnet / Security Group（必要に応じて）
├── ec2.tf               # Ollama 用 EC2 定義
├── lambda.tf            # Lambda 関数定義
├── api_gateway.tf       # API Gateway 定義
├── iam.tf               # IAM ロール / ポリシー定義
├── outputs.tf           # エンドポイントや接続情報の出力
├── dev.tfvars           # 開発環境用変数
├── prod.tfvars          # 本番環境用変数
├── user_data.sh         # EC2 初期化スクリプト（Ollama インストール等）
└── src/
    └── lambda_function.py  # Lambda 中継処理
```

## 実装ステップ

### Step 1: プロジェクト共通設定

- `provider.tf` : AWS プロバイダ、リージョン、default_tags を定義
- `variables.tf` : プロジェクト名、環境名、使用モデル、EC2 インスタンスタイプなどを定義
- `dev.tfvars` / `prod.tfvars` : 環境差分を管理

### Step 2: ネットワーク / セキュリティ設計

- EC2 を配置するネットワークを定義
- Lambda から EC2 の Ollama ポートへ通信できる構成を検討
- EC2 への直接外部公開は極力避け、Security Group でアクセス元を制限
- SSH の扱いは学習用として明示しつつ、可能なら Session Manager を優先

### Step 3: EC2 + Ollama サーバー

- `ec2.tf` で Ollama 実行用インスタンスを作成
- `user_data.sh` で以下を自動化:
  - Ollama のインストール
  - サービス起動設定
  - `qwen2.5:0.5b` の pull
  - 必要なら systemd / 再起動時自動起動の設定
- 推論コストと性能のバランスを見て、まずは軽量なインスタンスタイプから開始

### Step 4: Lambda 中継関数

- `src/lambda_function.py` で API Gateway からの入力を受け取る
- リクエスト本文から `prompt` を取得し、EC2 上の Ollama API に転送
- タイムアウト、接続失敗、Ollama 未起動時のエラーを整形して返却
- 将来的に `model` や `stream` のようなパラメータを受け取れるように拡張しやすくする

### Step 5: API Gateway

- `POST /generate` エンドポイントを作成
- Lambda プロキシ統合でシンプルに接続
- 必要なら API キー、CORS、スロットリングを後から追加可能な構成にする

### Step 6: IAM / 監視

- Lambda 実行ロールに CloudWatch Logs 権限を付与
- EC2 は最小権限を基本とし、SSM 利用時のみ必要なロールを付与
- CloudWatch Logs で Lambda と初期化ログを確認できるようにする

### Step 7: テストと運用確認

- Terraform apply 後に API エンドポイントを出力
- `curl` などで `POST /generate` を呼び出して応答確認
- EC2 上で Ollama が起動しているか、モデルが取得済みかを確認
- Lambda タイムアウト値と EC2 の応答速度のバランスを調整

## 学習ポイント

1. **EC2 上での LLM 実行**: マネージドサービスではなく、自前ホストでモデルを動かす基本構成
2. **Lambda を中継にした API 化**: 直接 EC2 を公開せずに API 層を分離する設計
3. **Security Group 設計**: どこからどこへ通信させるかを明確にする考え方
4. **初期化自動化**: `user_data` によるサーバーセットアップの自動化
5. **推論 API の実運用課題**: コールドスタート、モデルロード時間、タイムアウト、コスト

## 注意事項

- `qwen2.5:0.5b` は軽量だが、EC2 スペック次第では初回ロードや応答時間が長くなる
- Lambda から EC2 へ通信する場合、ネットワーク構成（パブリック / プライベート、NAT の有無）を先に整理する必要がある
- Ollama のデフォルト待ち受け設定やバインドアドレスは、外部公開しない前提で慎重に扱う
- 生成 AI API は長時間応答になることがあるため、Lambda / API Gateway のタイムアウト制限を意識する
- 将来的に認証を追加するなら、API Gateway の認証や Lambda 側での簡易認可も検討する
