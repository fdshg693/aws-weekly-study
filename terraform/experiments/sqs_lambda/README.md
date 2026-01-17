# Lambda + SQS サーバーレスアプリ

## 概要
AWS Lambda と SQS の連携パターンを Terraform で構築し、サーバーレスアーキテクチャの基礎を学習するためのプロジェクトです。

### 技術スタック
- **IaC**: Terraform（モジュール構成）
- **コンピューティング**: AWS Lambda（Python 3.12）
- **メッセージキュー**: Amazon SQS（標準キュー + DLQ）
- **データベース**: Amazon DynamoDB
- **API**: Amazon API Gateway（REST API）
- **ログ**: Amazon CloudWatch Logs

### 作成物
HTTP POST リクエストで注文データを受け付け、非同期処理でDynamoDBに保存するサーバーレスアプリケーションです。以下の流れで動作します：

1. API Gateway経由で注文データを受信
2. Producer LambdaがSQSキューにメッセージを送信
3. Consumer LambdaがSQSからメッセージを取得
4. 注文データをDynamoDBに永続化
5. 処理失敗時は自動的にDead Letter Queueに移動

エラーハンドリングとリトライ機構を備えた、本番環境でも使用可能な非同期処理パターンを実装しています。

## 構成ファイル
- [main.tf](main.tf) - ルートモジュール（各モジュールの呼び出し）
- [modules/lambda/](modules/lambda/) - Lambda関数の汎用モジュール（IAMロール、イベントソースマッピング含む）
- [modules/sqs/](modules/sqs/) - SQSキューとDLQの定義
- [modules/api_gateway/](modules/api_gateway/) - API Gateway REST APIの設定
- [modules/dynamodb/](modules/dynamodb/) - DynamoDBテーブルの定義
- [lambda_code/producer/index.py](lambda_code/producer/index.py) - 注文受付とSQS送信ロジック
- [lambda_code/consumer/index.py](lambda_code/consumer/index.py) - SQS読み取りとDynamoDB保存ロジック

## コードの特徴

### 1. モジュール化によるコンポーネント分離
各AWSサービスを独立したモジュールとして実装し、再利用性と保守性を向上させています。特にLambdaモジュールは汎用的な設計となっており、Producer/Consumer両方で使用可能です。

### 2. IAM最小権限の原則
各Lambdaには必要最小限の権限のみを付与：
- Producer: SQS SendMessage権限のみ
- Consumer: SQS受信、DynamoDB書き込み、CloudWatch Logs書き込み

### 3. 部分バッチ応答の実装
Consumer LambdaでSQSの`ReportBatchItemFailures`を使用し、バッチ内の一部メッセージのみ失敗した場合でも、成功したメッセージは削除される仕組みを実装しています。

### 4. Dead Letter Queueによるエラーハンドリング
3回の再試行後も処理できなかったメッセージをDLQに隔離し、システム全体の安定性を確保しています。

### 5. CloudWatch Logsの構造化ログ
JSON形式で構造化されたログを出力し、CloudWatch Logs Insightsでの分析を容易にしています。

## 注意事項
- Lambda同時実行数を5に制限しているため、大量のリクエストを処理する場合は`reserved_concurrent_executions`の調整が必要です
- SQSの可視性タイムアウトとLambdaのタイムアウトは同じ値（30秒）に設定する必要があります
- DLQに移動したメッセージは自動削除されないため、定期的な確認と再処理またはクリーンアップが必要です
- CloudWatch Logsの保持期間は7日間に設定されているため、長期保存が必要な場合は設定変更してください
- API GatewayのエンドポイントはHTTPSですが、認証は実装されていないため、本番使用時はCognitoやIAM認証の追加を推奨します
