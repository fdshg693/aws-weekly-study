# 実装計画書

## 実装するコンポーネント

### 1. アーキテクチャ概要
```
[API Gateway] → [Producer Lambda] → [SQS Queue] → [Consumer Lambda] → [DynamoDB]
                                         ↓
                                   [Dead Letter Queue]
```

### 2. 実装ファイル一覧

```
terraform/sqs_lambda/
├── main.tf              # ルートモジュール（モジュール呼び出し）
├── variables.tf         # 変数定義
├── outputs.tf           # 出力定義
├── provider.tf          # AWS プロバイダー設定
├── dev.tfvars           # dev 環境の変数値
├── modules/
│   ├── lambda/
│   │   ├── main.tf      # Lambda 関数、IAM ロール、CloudWatch Logs
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── sqs/
│   │   ├── main.tf      # SQS キュー、DLQ、イベントソースマッピング
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── api_gateway/
│   │   ├── main.tf      # API Gateway REST API
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── dynamodb/
│       ├── main.tf      # DynamoDB テーブル
│       ├── variables.tf
│       └── outputs.tf
└── lambda_code/
    ├── producer/
    │   └── index.py     # Producer Lambda コード
    └── consumer/
        └── index.py     # Consumer Lambda コード
```

### 3. 設定値

| リソース | 設定項目 | 値 |
|---------|---------|-----|
| Lambda | ランタイム | Python 3.12 |
| Lambda | メモリ | 128MB |
| Lambda | タイムアウト | 30秒 |
| Lambda | 同時実行数 | 5 |
| SQS | メッセージ保持期間 | 4日間（345600秒） |
| SQS | 可視性タイムアウト | 30秒 |
| SQS | DLQ 移動 | 3回失敗後 |
| CloudWatch Logs | 保持期間 | 7日間 |
| DynamoDB | 課金モード | PAY_PER_REQUEST（オンデマンド） |

### 4. IAM 権限設計

#### Producer Lambda
- SQS: SendMessage
- CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents

#### Consumer Lambda
- SQS: ReceiveMessage, DeleteMessage, GetQueueAttributes
- DynamoDB: PutItem, UpdateItem, GetItem
- CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents

## 確認事項

この計画で実装を進めてよろしいでしょうか？

- [ ] アーキテクチャ構成は要件通りか
- [ ] モジュール分割は適切か
- [ ] 設定値は適切か
- [ ] IAM 権限は最小限になっているか

---

**コマンド実行後、確認をお願いします。**
