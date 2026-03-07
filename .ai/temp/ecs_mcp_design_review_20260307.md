# ECS MCP 設計レビューメモ（2026-03-07）

対象:
- `terra_dev/ecs_mcp/PLAN.md`
- `terra_dev/ecs_mcp/python/main.py`
- 参考 `terra_dev/ecs/README.md`
- 参考 `terra_dev/ecs/provider.tf`
- 参考 `terra_dev/ecs/ecs.tf`

## ローカル確認結果
- `PLAN.md` は以下の要件を列挙: Docker化、ECR push、ECS Fargate サービス、ALB `/mcp` 転送、ACM HTTPS、認証、CloudWatch ログ/メトリクス。
- `python/main.py` は `FastMCP("Demo 🚀")` と `mcp.run()` のみ。待受アドレス・ポート・ヘルスチェック・認証連携の実装は見当たらない。
- 参考 `terra_dev/ecs` は、ECS クラスター + CloudWatch Logs + タスク定義 + ECS Service の最小構成サンプル。`containerInsights` 有効、awslogs 送信あり。

## 設計判断メモ
### 認証方式
- アプリ無改修で現実的なのは **ALB listener rule の `authenticate-cognito`**。
- 理由:
  - ALB が認証をオフロードでき、アプリ実装不要。
  - AWS内で完結し、Terraform管理しやすい。
  - `authenticate-cognito` / `authenticate-oidc` は **HTTPS listener でのみ利用可能**。

### HTTPS / 証明書前提
- ALB の HTTPS listener には少なくとも 1 つの証明書が必要。
- 証明書のドメイン名は、公開するカスタムドメインと一致する必要がある。
- ACM 公開証明書を DNS validation で使う場合、対象ドメインの DNS に CNAME を追加できる必要がある。
- Route 53 を使うなら public hosted zone があると Terraform 自動化しやすい。
- カスタムドメインで公開するなら Route 53 alias record → ALB が必要。

### ECS + ALB 前提
- Fargate / `awsvpc` では target group の `target_type` は **`ip`** 必須。
- ECS service ごとに target group を分ける。
- ALB の subnet は、タスクを配置する AZ をカバーする必要がある。
- タスクが LB health check に失敗すると ECS が再起動を繰り返すため、health check path / timeout / grace period は重要。

### 観測性
- アプリログは `awslogs` で CloudWatch Logs に送る。
- ECS cluster では Container Insights を有効化すると、CloudWatch で cluster / service / task メトリクスを見やすい。

## 参考ドキュメント
- ALB 認証: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html
- ECS + ALB: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html
- ECS health check 最適化: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/load-balancer-healthcheck.html
- ALB 証明書: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html
- ACM DNS validation: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
- Container Insights: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html
- Route 53 alias → ELB: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html
