# Lambda + SQS サーバーレスアプリ

## 概要

このプロジェクトは、AWS Lambda と SQS の連携パターンを Terraform で構築し、サーバーレスアーキテクチャの基礎を学習するためのものです。

## アーキテクチャ

```
[API Gateway] → [Producer Lambda] → [SQS Queue] → [Consumer Lambda] → [DynamoDB]
                                         ↓
                                   [Dead Letter Queue]
```

### コンポーネント

| リソース | 説明 |
|---------|------|
| API Gateway | REST API エンドポイント（POST /orders） |
| Producer Lambda | 注文リクエストを受け取り、SQS にメッセージを送信 |
| SQS Queue | メッセージキュー（標準キュー） |
| Dead Letter Queue | 処理失敗メッセージの格納用 |
| Consumer Lambda | SQS からメッセージを取得し、DynamoDB に保存 |
| DynamoDB | 注文データの永続化 |

## ディレクトリ構成

```
terraform/sqs_lambda/
├── main.tf                    # ルートモジュール（モジュール呼び出し）
├── variables.tf               # 変数定義
├── outputs.tf                 # 出力定義
├── provider.tf                # AWS プロバイダー設定
├── dev.tfvars                 # dev 環境の変数値
├── modules/
│   ├── api_gateway/           # API Gateway モジュール
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dynamodb/              # DynamoDB モジュール
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── lambda/                # Lambda モジュール（汎用）
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── sqs/                   # SQS モジュール
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── lambda_code/
    ├── producer/
    │   └── index.py           # Producer Lambda コード
    └── consumer/
        └── index.py           # Consumer Lambda コード
```

## 使い方

### 1. 初期化

```bash
cd terraform/sqs_lambda
terraform init
```

### 2. プラン確認

```bash
terraform plan -var-file=dev.tfvars
```

### 3. デプロイ

```bash
terraform apply -var-file=dev.tfvars
```

### 4. テスト

デプロイ後、出力される `test_curl_command` を使用してテストできます：

```bash
# 注文を作成
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "田中太郎",
    "items": [
      {"name": "商品A", "quantity": 2, "price": 1000},
      {"name": "商品B", "quantity": 1, "price": 500}
    ],
    "total_amount": 2500
  }' \
  https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/dev/orders
```

### 5. ログ確認

```bash
# Producer Lambda のログ
aws logs tail /aws/lambda/order-processor-producer-dev --follow

# Consumer Lambda のログ
aws logs tail /aws/lambda/order-processor-consumer-dev --follow
```

### 6. DynamoDB 確認

```bash
aws dynamodb scan --table-name order-processor-orders-dev
```

### 7. クリーンアップ

```bash
terraform destroy -var-file=dev.tfvars
```

## 設定値

| 項目 | 値 | 説明 |
|------|-----|------|
| Lambda ランタイム | Python 3.12 | 最新の LTS バージョン |
| Lambda メモリ | 128MB | 学習用の最小構成 |
| Lambda タイムアウト | 30秒 | 一般的な処理時間 |
| 同時実行数 | 5 | コスト抑制 |
| SQS メッセージ保持 | 4日間 | 十分なリトライ期間 |
| 可視性タイムアウト | 30秒 | Lambda タイムアウトと同じ |
| DLQ 移動 | 3回失敗後 | エラーの早期検出 |
| ログ保持期間 | 7日間 | 学習用に短め |

## 学習ポイント

### 1. IAM ロール・ポリシー設計
- Lambda に必要な最小権限の付与
- SQS へのアクセス権限
- DynamoDB へのアクセス権限
- CloudWatch Logs へのログ出力権限

### 2. SQS イベントソースマッピング
- Lambda と SQS の接続
- バッチサイズの設定
- 部分バッチ応答（ReportBatchItemFailures）

### 3. Dead Letter Queue
- 処理失敗メッセージの隔離
- リトライ回数の制御
- 後続の調査・再処理

### 4. CloudWatch Logs
- 構造化ログの出力
- ログ保持期間の設定
- ログの検索・分析

### 5. Terraform モジュール化
- 再利用可能な構成
- 変数によるカスタマイズ
- 出力による連携

## 拡張アイデア

1. **認証の追加**: Cognito または IAM 認証
2. **FIFO キューへの移行**: 順序保証が必要な場合
3. **X-Ray トレーシング**: 分散トレーシングの可視化
4. **アラーム設定**: DLQ へのメッセージ到達時に通知
5. **VPC 配置**: プライベートサブネットでの実行

## トラブルシューティング

### Lambda がタイムアウトする
- `lambda_timeout` を増やす
- `sqs_visibility_timeout_seconds` も同様に増やす

### メッセージが DLQ に移動する
- CloudWatch Logs でエラー内容を確認
- `sqs_max_receive_count` を増やしてリトライ回数を調整

### API Gateway から 500 エラー
- Producer Lambda のログを確認
- 環境変数 `SQS_QUEUE_URL` が正しく設定されているか確認
