# Lambda関数デプロイメント

## 概要
PythonスクリプトをAWS Lambda関数にデプロイするためのTerraform構成です。開発から本番環境まで対応できる実践的な設定を提供します。

### 技術スタック
- AWS Lambda（Python 3.12）
- Terraform
- IAM Role & Policy
- CloudWatch Logs
- X-Ray（オプション）

### 作成物
イベント駆動型のサーバーレス関数です。入力されたイベントデータを処理し、レスポンスを返します。開発環境では最小限のリソース（128MB、3秒）で動作し、本番環境では十分なリソース（512MB、30秒）とX-Rayトレーシングによる監視を備えています。

## 構成ファイル
- `lambda.tf` - Lambda関数のリソース定義
- `iam.tf` - Lambda実行ロールと権限ポリシー
- `variables.tf` - 変数定義（詳細なコメント付き）
- `outputs.tf` - デプロイ後の出力値
- `dev.tfvars` / `prod.tfvars` - 環境別設定ファイル
- `src/lambda_function.py` - Lambda関数のPythonコード
- `test_lambda_local.sh` - ローカルテストスクリプト

## コードの特徴
- **自動デプロイメカニズム**: `archive_file`データソースを使用してソースコードの変更を自動検知し、`terraform apply`で自動更新します。
- **IAM権限の最小化**: 最小権限の原則に基づき、CloudWatch Logsへの書き込み権限のみをデフォルトで設定。追加権限は`iam.tf`で明示的に定義します。
- **環境別の最適化**: 開発環境では低コストで迅速なイテレーション、本番環境では高パフォーマンスと安定性を重視した設定を実現しています。
- **拡張可能な設計**: `variables.tf`にVPC統合、DLQ、Lambda Layers、予約済み同時実行数など、様々なオプション機能の例とコメントを記載しており、必要に応じて簡単に有効化できます。

## 注意事項
- Lambda関数のコードを変更した場合、必ず`terraform apply`を実行してデプロイしてください
- IAM権限を追加する場合は、`iam.tf`のカスタムポリシーセクションを編集してください
- VPC内でLambda関数を実行する場合、NAT Gatewayが必要です（インターネットアクセスのため）
- CloudWatch Logsのログ保持期間を長く設定すると、コストが増加する可能性があります
