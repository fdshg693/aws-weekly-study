# ECS Fargate - 実装プラン

## 概要

ECS Fargate + ALB を使って、コンテナベースのWebアプリケーションをデプロイする。
シンプルなNginx Webサーバーをコンテナとして起動し、ALB経由でアクセスできる構成を構築する。
EC2プロジェクトの発展形として、コンテナオーケストレーションの基本を学ぶ。

## アーキテクチャ

```
クライアント
  ↓ HTTP (ポート80)
ALB (Application Load Balancer)
  ↓ ターゲットグループ
ECS Fargate タスク (Nginx コンテナ)
  ↑ イメージ取得
ECR (Elastic Container Registry)
```

### ネットワーク構成

```
VPC (10.0.0.0/16)
├── パブリックサブネット x2 (ALB用、AZ分散)
│   ├── 10.0.1.0/24 (ap-northeast-1a)
│   └── 10.0.2.0/24 (ap-northeast-1c)
├── プライベートサブネット x2 (ECSタスク用、AZ分散)
│   ├── 10.0.10.0/24 (ap-northeast-1a)
│   └── 10.0.11.0/24 (ap-northeast-1c)
├── Internet Gateway
├── NAT Gateway (プライベートサブネットからの外部通信用)
└── ルートテーブル
```

## 技術スタック

- **ECS (Fargate)**: コンテナオーケストレーション（サーバーレスコンピュート）
- **ECR**: Dockerイメージの保存・管理
- **ALB**: ロードバランサーによるHTTPトラフィック分散
- **VPC**: ネットワーク分離（パブリック/プライベートサブネット）
- **NAT Gateway**: プライベートサブネットからの外部通信
- **IAM**: ECSタスク実行ロール（ECRからのイメージ取得、CloudWatch Logs出力）
- **CloudWatch Logs**: コンテナログの収集

## 作成物

- ALBのDNS名でアクセスするとNginxのウェルカムページが表示される
- ECS Fargateタスクとして起動したコンテナが自動的にALBに登録される
- コンテナの異常終了時はECSサービスが自動的に新しいタスクを起動する

## 構成ファイル（予定）

```
ecs/
├── PLAN.md              # 本ファイル（実装プラン）
├── README.md            # プロジェクト説明
├── provider.tf          # AWSプロバイダ設定
├── variables.tf         # 変数定義
├── vpc.tf               # VPC、サブネット、IGW、NAT GW、ルートテーブル
├── security_groups.tf   # ALB用・ECSタスク用セキュリティグループ
├── alb.tf               # ALB、ターゲットグループ、リスナー
├── ecr.tf               # ECRリポジトリ
├── ecs.tf               # ECSクラスター、タスク定義、サービス
├── iam.tf               # ECSタスク実行ロール
├── outputs.tf           # 出力定義（ALB DNS名等）
├── dev.tfvars           # 開発環境用変数
├── prod.tfvars          # 本番環境用変数
└── docker/
    ├── Dockerfile       # Nginxカスタムイメージ
    └── index.html       # カスタムウェルカムページ
```

## 実装ステップ

### Step 1: 基盤構築

- `provider.tf` : AWSプロバイダ設定（ap-northeast-1、default_tags）
- `variables.tf` : プロジェクト名、環境、リージョン、コンテナ設定（CPU/メモリ/ポート/台数）等の変数定義
- `dev.tfvars` / `prod.tfvars` : 環境ごとの値

### Step 2: VPC・ネットワーク

- `vpc.tf` で以下を定義:
  - VPC（10.0.0.0/16）
  - パブリックサブネット x2（ALB配置用、AZ分散必須）
  - プライベートサブネット x2（ECSタスク配置用）
  - Internet Gateway
  - NAT Gateway（プライベートサブネット → 外部通信、ECRからのイメージ取得に必要）
  - ルートテーブルとアソシエーション

### Step 3: セキュリティグループ

- `security_groups.tf` で以下を定義:
  - ALB用: インバウンド HTTP(80) を許可、アウトバウンド全許可
  - ECSタスク用: ALBからのインバウンドのみ許可（ALBセキュリティグループを参照）、アウトバウンド全許可

### Step 4: ALB

- `alb.tf` で以下を定義:
  - ALB本体（パブリックサブネットに配置）
  - ターゲットグループ（target_type = "ip"、Fargate必須）
  - ヘルスチェック設定（パス、間隔、しきい値）
  - リスナー（HTTP:80 → ターゲットグループにフォワード）

### Step 5: ECR

- `ecr.tf` で以下を定義:
  - ECRリポジトリの作成
  - イメージのミュータビリティ設定（IMMUTABLE推奨）
  - ライフサイクルポリシー（古いイメージの自動削除）

### Step 6: IAM

- `iam.tf` で以下を定義:
  - ECSタスク実行ロール（AssumeRole: ecs-tasks.amazonaws.com）
  - AmazonECSTaskExecutionRolePolicy のアタッチ（ECRイメージ取得 + CloudWatch Logs）
  - 必要に応じてタスクロール（コンテナ内からAWSサービスへのアクセス用、今回は不要）

### Step 7: ECS

- `ecs.tf` で以下を定義:
  - ECSクラスター
  - タスク定義（Fargate互換）
    - コンテナ定義（イメージ、ポートマッピング、ログ設定）
    - CPU / メモリの指定（dev: 256/512、prod: 512/1024）
    - ネットワークモード: awsvpc（Fargate必須）
  - ECSサービス
    - 希望タスク数（dev: 1、prod: 2）
    - ネットワーク設定（プライベートサブネット、セキュリティグループ）
    - ALBとの連携（ターゲットグループへの登録）

### Step 8: Docker イメージとデプロイ

- `docker/Dockerfile` : Nginx公式イメージベースのカスタムイメージ
- `docker/index.html` : シンプルなウェルカムページ
- README.md にイメージのビルド・プッシュ手順を記載:
  ```bash
  # ECRログイン
  aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-northeast-1.amazonaws.com
  # ビルド & プッシュ
  docker build -t <repo_name> docker/
  docker tag <repo_name>:latest <ecr_uri>:latest
  docker push <ecr_uri>:latest
  ```

### Step 9: 出力とテスト

- `outputs.tf` : ALB DNS名、ECSクラスター名、ECRリポジトリURL、ECSサービス名を出力
- ALB DNS名にブラウザでアクセスしてNginxページの表示を確認

## 学習ポイント

1. **ECS Fargate**: EC2を管理せずにコンテナを実行するサーバーレスコンピュート
2. **ECR**: コンテナイメージのライフサイクル管理
3. **ALB + ECS連携**: ターゲットタイプ "ip" によるFargateタスクへのルーティング
4. **VPCネットワーク設計**: パブリック/プライベートサブネットの分離とNAT Gatewayの役割
5. **セキュリティグループ連鎖**: ALB → ECSタスク間のセキュリティグループ参照パターン

## 注意事項

- **NAT Gatewayのコスト**: 時間課金（約$0.062/h ≒ $45/月）が発生するため、使わない時は `terraform destroy` を忘れずに
- **ECRイメージの事前準備**: Terraform apply の前にDockerイメージをECRにプッシュする必要がある（初回デプロイ時）
- **Fargateの制約**: CPU/メモリの組み合わせに制限あり（256 CPU → 512/1024/2048 メモリ等）
- **ヘルスチェック**: ALBのヘルスチェックが通らないとタスクが繰り返し再起動されるので、設定に注意
- **AZ分散**: ALBは最低2つのAZのサブネットが必要
