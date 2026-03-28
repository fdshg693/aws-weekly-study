# Lambda関数デプロイメント

## 概要
PythonスクリプトをAWS Lambda関数にデプロイするためのTerraform構成です。開発から本番環境まで対応できる実践的な設定を提供します。

### 技術スタック
- AWS Lambda（Python 3.12）
- Amazon API Gateway（HTTP API）

- Terraform
- IAM Role & Policy
- CloudWatch Logs
- X-Ray（オプション）

### 作成物
イベント駆動型のサーバーレス関数です。入力されたイベントデータを処理し、レスポンスを返します。開発環境では最小限のリソース（128MB、3秒）で動作し、本番環境では十分なリソース（512MB、30秒）とX-Rayトレーシングによる監視を備えています。

## 構成ファイル
- `lambda.tf` - Lambda関数のリソース定義
- `api_gateway.tf` - API Gateway HTTP APIとLambda統合の定義
- `iam.tf` - Lambda実行ロールと権限ポリシー
- `variables.tf` - 変数定義（詳細なコメント付き）
- `outputs.tf` - デプロイ後の出力値
- `dev.tfvars` / `prod.tfvars` - 環境別設定ファイル
- `Makefile` - Terraform操作とAPIテストのショートカット
- `src/lambda_function.py` - Lambda関数のPythonコード
- `test_api.sh` - API Gateway経由の疎通テストスクリプト
- `k6_api_test.js` - k6 を使った GET/POST の負荷試験スクリプト

## コードの特徴
- **自動デプロイメカニズム**: `archive_file`データソースを使用してソースコードの変更を自動検知し、`terraform apply`で自動更新します。
- **HTTP API公開**: Amazon API Gateway HTTP APIを追加し、`GET /` と `POST /` の両方でLambda関数を呼び出せます。
- **IAM権限の最小化**: 最小権限の原則に基づき、CloudWatch Logsへの書き込み権限のみをデフォルトで設定。追加権限は`iam.tf`で明示的に定義します。
- **環境別の最適化**: 開発環境では低コストで迅速なイテレーション、本番環境では高パフォーマンスと安定性を重視した設定を実現しています。
- **拡張可能な設計**: `variables.tf`にVPC統合、DLQ、Lambda Layers、予約済み同時実行数など、様々なオプション機能の例とコメントを記載しており、必要に応じて簡単に有効化できます。

## 使い方

### デプロイ
- 開発環境: `make apply ENV=dev`
- 本番環境: `make apply ENV=prod`

### 出力確認
- `make output`
- `terraform output -raw api_invoke_url`

### API テスト
- `make test ENV=dev`
- 必要に応じて `REQUEST_NAME`, `REQUEST_MESSAGE`, `API_URL` を環境変数で上書き可能です。

### 負荷テスト（k6）
- `make load-test ENV=prod`
- 必要に応じて `API_URL`, `REQUEST_NAME`, `REQUEST_MESSAGE` を指定できます
- k6 が未インストールなら `brew install k6` で導入できます
- 実行結果は `logs/` 配下にタイムスタンプ付きで保存されます
  - 標準出力ログ: `logs/k6-load-test-YYYYMMDD-HHMMSS.log`
  - サマリーJSON: `logs/k6-load-test-YYYYMMDD-HHMMSS-summary.json`

例:
```bash
make load-test ENV=prod

API_URL="https://xxxx.execute-api.ap-northeast-1.amazonaws.com/" \
REQUEST_NAME="benchmark" \
REQUEST_MESSAGE="Hello from load test" \
make load-test ENV=prod
```

テスト実行後は `logs/` フォルダを見れば、あとから結果を見返せます。

`k6_api_test.js` は GET / POST を別シナリオで同時に実行し、以下を確認しやすくしています。
- API Gateway のスロットリングによる `429` の発生有無
- `http_req_duration` の p95 など、応答速度の悪化ポイント
- GET / POST それぞれの成功率

さらに細かくレートを調整したい場合は、環境変数で変更できます。

例:
```bash
API_URL="https://xxxx.execute-api.ap-northeast-1.amazonaws.com/" \
GET_STAGE1_TARGET=10 GET_STAGE2_TARGET=30 GET_STAGE3_TARGET=60 \
POST_STAGE1_TARGET=5 POST_STAGE2_TARGET=15 POST_STAGE3_TARGET=30 \
k6 run ./k6_api_test.js
```

## 注意事項
- Lambda関数のコードを変更した場合、必ず`terraform apply`を実行してデプロイしてください
- API GatewayのURLは `terraform output -raw api_invoke_url` で確認できます
- IAM権限を追加する場合は、`iam.tf`のカスタムポリシーセクションを編集してください
- VPC内でLambda関数を実行する場合、NAT Gatewayが必要です（インターネットアクセスのため）
- CloudWatch Logsのログ保持期間を長く設定すると、コストが増加する可能性があります
