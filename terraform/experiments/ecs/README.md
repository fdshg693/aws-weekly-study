# ECS Fargate + ALB サンプル

ECS Fargate + ALB を使って、Nginxコンテナをデプロイするサンプルプロジェクト。

## アーキテクチャ

```
クライアント → ALB (HTTP:80) → ECS Fargate タスク (Nginx) ← ECR (イメージ取得)
```

- ALB: パブリックサブネットに配置（2AZ分散）
- ECS Fargate: プライベートサブネットに配置（NAT Gateway経由で外部通信）

## 使い方

### 1. Terraformの初期化とECR作成

```bash
cd terraform/experiments/ecs

terraform init

# まずECRリポジトリだけ作成（イメージをプッシュするため）
terraform apply -var-file=dev.tfvars -target=aws_ecr_repository.main
```

### 2. Dockerイメージのビルドとプッシュ

```bash
# ECRリポジトリURLを取得
ECR_URI=$(terraform output -raw ecr_repository_url)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-1

# ECRにログイン
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# ビルド & プッシュ
docker build -t ecs-sample docker/
docker tag ecs-sample:latest $ECR_URI:v1
docker push $ECR_URI:v1
```

### 3. 全リソースのデプロイ

```bash
# container_image にプッシュしたイメージのURIを指定
terraform apply -var-file=dev.tfvars -var="container_image=${ECR_URI}:v1"
```

### 4. 動作確認

```bash
# ALBのDNS名を確認
terraform output alb_dns_name

# ブラウザでアクセス、またはcurlで確認
curl $(terraform output -raw alb_dns_name | sed 's|http://||')
```

### 5. リソースの削除

```bash
# NAT Gatewayは時間課金（約$0.062/h ≒ $45/月）なので、使い終わったら必ず削除
terraform destroy -var-file=dev.tfvars
```

## ファイル構成

| ファイル | 内容 |
|---|---|
| `provider.tf` | AWSプロバイダ設定 |
| `variables.tf` | 変数定義 |
| `vpc.tf` | VPC、サブネット、IGW、NAT Gateway、ルートテーブル |
| `security_groups.tf` | ALB用・ECSタスク用セキュリティグループ |
| `alb.tf` | ALB、ターゲットグループ、リスナー |
| `ecr.tf` | ECRリポジトリ、ライフサイクルポリシー |
| `iam.tf` | ECSタスク実行ロール |
| `ecs.tf` | ECSクラスター、タスク定義、サービス |
| `outputs.tf` | 出力定義 |
| `docker/` | Dockerfile、カスタムウェルカムページ |
| `dev.tfvars` | 開発環境用変数（CPU: 256, メモリ: 512, タスク数: 1） |
| `prod.tfvars` | 本番環境用変数（CPU: 512, メモリ: 1024, タスク数: 2） |

## コスト注意

- **NAT Gateway**: 約$45/月（時間課金）が発生します。使わない時は `terraform destroy` を忘れずに。
- **ALB**: 約$16/月 + データ転送量
- **Fargate**: タスクのCPU/メモリと稼働時間に応じた課金
