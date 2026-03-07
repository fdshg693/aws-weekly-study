# ECS Fargate + ALB サンプル

ECS Fargate + ALB を使って、Nginxコンテナをデプロイするサンプルプロジェクト。

## アーキテクチャ

```
クライアント → ALB (HTTP:80) → ECS Fargate タスク (Nginx) ← ECR (イメージ取得)
```

- ALB: パブリックサブネットに配置（2AZ分散）
- ECS Fargate: プライベートサブネットに配置（NAT Gateway経由で外部通信）

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
