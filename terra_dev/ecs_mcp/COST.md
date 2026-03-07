# コスト見積もり & 最適化ガイド

このドキュメントでは、本プロジェクト（ECS Fargate + ALB + Cognito）の AWS 利用コストと最適化方法をまとめる。

> 料金は **東京リージョン（ap-northeast-1）** の 2025 年時点の公開料金に基づく。
> 最新の料金は [AWS 料金ページ](https://aws.amazon.com/pricing/) を確認すること。

---

## 1. リソース別コスト一覧

### 常時課金（24h/365d 稼働前提）

| リソース | 単価 | 月額目安 | 備考 |
|---|---|---|---|
| **NAT Gateway** | $0.062/h + $0.062/GB | **~$45.26** | 最大のコスト要因 |
| **ALB** | $0.0243/h + $0.008/LCU-h | **~$17.74** + LCU | LCU は低負荷なら微小 |
| **ECS Fargate (0.25 vCPU / 512 MB)** | CPU: $0.05056/vCPU/h, Mem: $0.00553/GB/h | **~$11.24** (1 タスク) | デフォルト設定の場合 |
| **Elastic IP** | $0.005/h (未使用時) | $0 | NAT GW に紐付いている間は無料 |

### 従量課金

| リソース | 単価 | 月額目安 | 備考 |
|---|---|---|---|
| **ECR** | $0.10/GB/月 | **~$0.01〜0.05** | 小さなイメージなら無視できる |
| **CloudWatch Logs** | 取り込み: $0.76/GB, 保存: $0.033/GB/月 | **~$0.10〜1.00** | ログ量次第 |
| **Container Insights** | $0.01/パフォーマンスイベント | **~$0.30〜1.00** | ECS クラスターで有効化済み |
| **NAT Gateway データ処理** | $0.062/GB | 通信量次第 | ECR pull / ログ送信等 |

### 条件付き（オプション機能）

| リソース | 単価 | 月額目安 | 条件 |
|---|---|---|---|
| **Cognito User Pool** | 50,000 MAU まで無料 | **$0** | `use_cognito = true` 時 |
| **Route53 Hosted Zone** | $0.50/ゾーン/月 | **$0.50** | `create_route53_record = true` 時 |
| **Route53 クエリ** | $0.40/100 万クエリ | 微小 | |
| **ACM 証明書** | 無料 | **$0** | パブリック証明書の場合 |

---

## 2. 月額コスト試算

### 最小構成（デフォルト設定 / タスク 1 台）

```
NAT Gateway (固定)        $45.26
ALB (固定)                $17.74
Fargate (0.25vCPU/512MB)  $11.24
CloudWatch Logs            $0.50
Container Insights         $0.50
ECR                        $0.05
──────────────────────────────────
合計                      ~$75/月（約 11,000 円）
```

### Cognito + Route53 込み

```
最小構成                   $75.29
Cognito                    $0.00  (50,000 MAU 無料枠内)
Route53                    $0.50
──────────────────────────────────
合計                      ~$76/月（約 11,400 円）
```

### タスク 2 台（冗長構成）

```
NAT Gateway               $45.26
ALB                       $17.74
Fargate x 2               $22.48
その他                     $1.05
──────────────────────────────────
合計                      ~$87/月（約 13,000 円）
```

---

## 3. コスト構造の分析

### コスト割合（最小構成）

```
NAT Gateway  ████████████████████  60%
ALB          ███████████           24%
Fargate      ██████                15%
その他        █                      1%
```

**NAT Gateway が全体の約 6 割** を占めており、最大のコスト要因である。

---

## 4. コスト最適化の方法

### A. NAT Gateway を VPC Endpoint に置き換える（効果: 大）

NAT Gateway（~$45/月）を廃止し、ECS タスクが必要とする AWS サービスへの通信を VPC Endpoint で代替する。

**必要な VPC Endpoint:**

| Endpoint | タイプ | 用途 | 月額目安 |
|---|---|---|---|
| `com.amazonaws.{region}.ecr.dkr` | Interface | ECR イメージ pull | ~$7.30 |
| `com.amazonaws.{region}.ecr.api` | Interface | ECR API | ~$7.30 |
| `com.amazonaws.{region}.s3` | Gateway | ECR イメージレイヤー (S3) | **無料** |
| `com.amazonaws.{region}.logs` | Interface | CloudWatch Logs | ~$7.30 |

```
変更前: NAT Gateway              $45.26/月
変更後: VPC Endpoint x 3         $21.90/月（Interface Endpoint $0.014/h x 2AZ x 3）
──────────────────────────────────
削減額:                          ~$23/月（約 50% 削減）
```

> **注意:** Interface Endpoint は AZ ごとに ENI を作成するため、1 AZ のみにすればさらに半額にできるが、可用性とのトレードオフになる。
> 学習用なら 1 AZ（~$10.95/月）でも十分。

**変更後の最小構成:**

```
VPC Endpoints (1AZ)        $10.95
ALB                        $17.74
Fargate                    $11.24
その他                      $1.05
──────────────────────────────────
合計                       ~$41/月（約 6,100 円）← 45% 削減
```

### B. 使わないときは desired_count = 0 にする（効果: 中）

学習用途であれば常時稼働は不要。使うときだけタスクを起動する。

```bash
# 停止
terraform apply -var-file=dev.tfvars -var="desired_count=0"

# 起動
terraform apply -var-file=dev.tfvars -var="desired_count=1"
```

Fargate 費用（~$11/月）をゼロにできる。ただし NAT Gateway や ALB の固定費は残る。

### C. ALB を削除してタスクを直接公開する（効果: 中 / 非推奨）

ALB（~$18/月）を廃止し、Fargate タスクに直接パブリック IP を割り当てる構成。

- HTTPS 終端を自前で行う必要がある
- ALB OIDC 認証が使えなくなる
- ヘルスチェック・ロードバランシングが失われる

**学習目的としてはデメリットが大きいため非推奨。**

### D. Fargate Spot を使う（効果: 小〜中）

Fargate Spot は通常料金の **最大 70% 割引** で利用できる。ただし中断リスクがある。

```hcl
# ECS サービスに capacity_provider_strategy を追加
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 1
}
```

```
通常 Fargate:  $11.24/月
Fargate Spot:  ~$3.37/月（70% 割引時）
削減額:        ~$8/月
```

学習用なら中断されても問題ないため有効。

### E. Container Insights を無効化する（効果: 小）

Container Insights は便利だが、学習初期段階では不要なことも多い。

```hcl
setting {
  name  = "containerInsights"
  value = "disabled"
}
```

~$0.50〜1.00/月の節約。

### F. CloudWatch Logs の保持期間を短縮する（効果: 小）

デフォルトの 30 日を 7 日や 3 日にする。

```hcl
variable "log_retention_in_days" {
  default = 7  # 30 → 7 に変更
}
```

---

## 5. 最適化の優先度まとめ

| 優先度 | 施策 | 削減額/月 | 難易度 | リスク |
|---|---|---|---|---|
| 1 | NAT GW → VPC Endpoint | ~$23〜34 | 中 | 低 |
| 2 | 未使用時 desired_count=0 | ~$11 | 低 | なし |
| 3 | Fargate Spot | ~$8 | 低 | 中断あり |
| 4 | Container Insights 無効化 | ~$1 | 低 | 監視性低下 |
| 5 | ログ保持期間短縮 | <$1 | 低 | なし |

---

## 6. 完全停止時のコスト

学習を一時中断する場合、`terraform destroy` で全リソースを削除すれば **$0** になる。

```bash
terraform destroy -var-file=dev.tfvars
```

`terraform destroy` せずにタスクだけ停止（`desired_count=0`）した場合:

```
NAT Gateway   $45.26   ← 停止不可（削除のみ）
ALB           $17.74   ← 停止不可（削除のみ）
Elastic IP     $3.65   ← NAT GW 削除後に未使用になると課金開始
──────────────────────
合計          ~$63/月（タスク停止でもインフラ固定費は残る）
```

**学習で使わない期間が長い場合は `terraform destroy` を推奨。**

---

## 7. AWS 無料利用枠の適用

新規アカウント（12 ヶ月以内）の場合、以下が無料枠に含まれる:

| サービス | 無料枠 | 本プロジェクトへの影響 |
|---|---|---|
| ALB | 750 時間/月 + 15 LCU | ALB 費用がほぼ無料 |
| NAT Gateway | **対象外** | 無料枠なし |
| Fargate | **対象外** | 無料枠なし |
| ECR | 500 MB/月 | イメージ保存が無料 |
| CloudWatch | 5 GB 取り込み + 5 GB 保存 | ログ費用が無料 |

無料枠ありのアカウントでは、ALB 費用が浮くため **~$57/月** 程度になる。
