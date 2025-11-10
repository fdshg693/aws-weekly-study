# Lambda関数 Terraform サンプル

## 概要

このディレクトリには、PythonスクリプトをAWS Lambda関数にデプロイするためのTerraform構成が含まれています。シンプルながら本番環境でも使用できる設定を提供し、様々なオプションや設定方法を詳細なコメントで説明しています。

## ディレクトリ構成

```
terraform/lambda/
├── README.md                   # このファイル
├── provider.tf                 # Terraformプロバイダー設定
├── variables.tf                # 変数定義（詳細なコメント付き）
├── lambda.tf                   # Lambda関数のリソース定義
├── iam.tf                      # IAMロールとポリシー定義
├── outputs.tf                  # 出力値定義
├── dev.tfvars                  # 開発環境用の設定
├── prod.tfvars                 # 本番環境用の設定
├── test_lambda_local.sh        # ローカルテストスクリプト
└── src/
    └── lambda_function.py      # Lambda関数のPythonコード
```

## 主な機能

### 1. Lambda関数の基本設定

- **ランタイム**: Python 3.12（他のランタイムにも変更可能）
- **自動デプロイ**: ソースコードの変更を自動検知してデプロイ
- **環境変数**: 柔軟な環境変数設定
- **リソース管理**: メモリサイズ、タイムアウトの細かい調整

### 2. セキュリティとアクセス制御

- **IAMロール**: Lambda実行用の専用ロール
- **最小権限の原則**: 必要最小限の権限のみ付与
- **CloudWatch Logs**: ログの自動記録と保持期間設定
- **X-Rayトレーシング**: パフォーマンス分析機能（オプション）

### 3. 環境別設定

- **開発環境** (`dev.tfvars`):
  - 最小限のリソース（128MB メモリ、3秒タイムアウト）
  - デバッグログ有効
  - 短いログ保持期間（7日）
  
- **本番環境** (`prod.tfvars`):
  - 高パフォーマンス設定（512MB メモリ、30秒タイムアウト）
  - 同時実行数の制限
  - 長いログ保持期間（90日）
  - X-Rayトレーシング有効

### 4. オプション機能

以下のオプション機能が `variables.tf` と `lambda.tf` にコメントで記載されています：

- **VPC統合**: プライベートリソース（RDS、ElastiCache等）へのアクセス
- **デッドレターキュー（DLQ）**: 失敗したイベントの処理
- **Lambda Layers**: 共通ライブラリの共有
- **コンテナイメージ**: Dockerイメージからのデプロイ
- **EFSマウント**: 永続的なファイルストレージ
- **予約済み同時実行数**: スロットリング制御
- **エイリアスとバージョン**: Blue/Greenデプロイメント
- **イベントソースマッピング**: S3、SQS、DynamoDB Streamsとの統合

## 使用方法

### 前提条件

- Terraform 1.0以上
- AWS CLI設定済み（認証情報）
- Python 3.9以上（ローカルテスト用）

### 1. 初期化

```bash
cd terraform/lambda
terraform init
```

### 2. 開発環境へのデプロイ

```bash
# プランの確認
terraform plan -var-file="dev.tfvars"

# デプロイ実行
terraform apply -var-file="dev.tfvars"
```

### 3. 本番環境へのデプロイ

```bash
# プランの確認
terraform plan -var-file="prod.tfvars"

# デプロイ実行
terraform apply -var-file="prod.tfvars"
```

### 4. 出力情報の確認

```bash
# すべての出力を表示
terraform output

# 特定の出力のみ表示
terraform output function_name
terraform output lambda_console_url

# JSON形式で出力
terraform output -json
```

### 5. リソースの削除

```bash
terraform destroy -var-file="dev.tfvars"
```

## ローカルテスト

デプロイ前にLambda関数をローカルでテストできます。

### テストスクリプトの使用方法

```bash
# 実行権限の付与（初回のみ）
chmod +x test_lambda_local.sh

# 対話モードで実行
./test_lambda_local.sh

# 基本テストのみ実行
./test_lambda_local.sh --quick

# すべてのテストを実行
./test_lambda_local.sh --all

# デプロイ後のテストを実行
./test_lambda_local.sh --deploy
```

### 手動でのテスト

```bash
# Pythonで直接実行
cd src
python3 -c "
import lambda_function
import os

os.environ['ENVIRONMENT'] = 'test'
os.environ['APP_NAME'] = 'test'

class MockContext:
    function_name = 'test'
    function_version = '1'
    aws_request_id = 'test-id'
    memory_limit_in_mb = 128
    def get_remaining_time_in_millis(self):
        return 300000

event = {'name': 'Test', 'message': 'Hello'}
result = lambda_function.lambda_handler(event, MockContext())
print(result)
"
```

## Lambda関数の呼び出しテスト（AWS CLI）

デプロイ後、AWS CLIを使用してLambda関数をテストできます。

```bash
# 基本的な呼び出し
aws lambda invoke \
  --function-name development-simple-lambda-function \
  --payload '{"name":"World","message":"Hello"}' \
  --region ap-northeast-1 \
  response.json

# レスポンスの確認
cat response.json | jq .

# ログの確認
aws logs tail /aws/lambda/development-simple-lambda-function \
  --follow \
  --region ap-northeast-1
```

## カスタマイズ

### Lambda関数のコードを変更

1. `src/lambda_function.py` を編集
2. ローカルでテスト: `./test_lambda_local.sh --quick`
3. 再デプロイ: `terraform apply -var-file="dev.tfvars"`

Terraformはソースコードの変更を自動検知し、Lambda関数を更新します。

### 環境変数の追加

`dev.tfvars` または `prod.tfvars` を編集：

```hcl
environment_variables = {
  LOG_LEVEL    = "DEBUG"
  DATABASE_URL = "postgresql://..."
  API_KEY      = "your-api-key"
  CUSTOM_VAR   = "custom-value"
}
```

### リソースの調整

メモリやタイムアウトを変更：

```hcl
memory_size = 256  # 128MB → 256MB
timeout     = 10   # 3秒 → 10秒
```

### VPC内での実行

`prod.tfvars` を編集：

```hcl
enable_vpc             = true
vpc_subnet_ids         = ["subnet-xxxxx", "subnet-yyyyy"]
vpc_security_group_ids = ["sg-xxxxx"]
```

### 追加のAWS権限を付与

`iam.tf` のカスタムポリシーセクションを編集：

```hcl
resource "aws_iam_role_policy" "lambda_custom_policy" {
  # ... 既存のコード ...
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = ["arn:aws:dynamodb:*:*:table/my-table"]
      }
    ]
  })
}
```

## 主要な変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|--------------|
| `aws_region` | AWSリージョン | `ap-northeast-1` |
| `environment` | 環境名 | `development` |
| `function_name` | Lambda関数名 | `simple-lambda-function` |
| `runtime` | ランタイム | `python3.12` |
| `memory_size` | メモリサイズ（MB） | `128` |
| `timeout` | タイムアウト（秒） | `3` |
| `log_retention_days` | ログ保持期間（日） | `7` |
| `tracing_mode` | X-Rayトレーシング | `PassThrough` |
| `enable_vpc` | VPC内で実行 | `false` |
| `reserved_concurrent_executions` | 同時実行数制限 | `-1` (制限なし) |

詳細は `variables.tf` を参照してください。

## 出力値

デプロイ後に取得できる主な出力値：

| 出力名 | 説明 |
|--------|------|
| `function_name` | Lambda関数名 |
| `function_arn` | Lambda関数のARN |
| `lambda_console_url` | AWSコンソールのURL |
| `cloudwatch_logs_url` | CloudWatch LogsのURL |
| `test_invoke_command` | テスト用のAWS CLIコマンド |
| `deployment_summary` | デプロイ情報のサマリー |

## トラブルシューティング

### Lambda関数が実行されない

1. IAMロールの権限を確認
2. CloudWatch Logsでエラーを確認：
   ```bash
   aws logs tail /aws/lambda/<function-name> --follow
   ```

### タイムアウトエラー

- `timeout` 変数の値を増やす
- メモリサイズを増やす（CPUも比例して向上）

### VPC内でインターネットにアクセスできない

- NAT Gatewayが設定されたプライベートサブネットを使用
- セキュリティグループのアウトバウンドルールを確認

### デプロイが遅い

- `archive_file` のキャッシュ問題の可能性
- `.terraform` ディレクトリを削除して `terraform init` を再実行

## ベストプラクティス

### 1. 最小権限の原則

IAMポリシーで必要最小限の権限のみを付与：

```hcl
# 悪い例: 広すぎる権限
Action = ["s3:*"]

# 良い例: 具体的な権限
Action = ["s3:GetObject", "s3:PutObject"]
Resource = ["arn:aws:s3:::specific-bucket/*"]
```

### 2. 環境変数で機密情報を管理

環境変数で設定ファイルを分離し、機密情報はAWS Secrets Managerを使用：

```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])
```

### 3. ログレベルの適切な設定

環境に応じてログレベルを変更：

- 開発: `DEBUG` - すべての詳細情報
- ステージング: `INFO` - 重要な情報のみ
- 本番: `WARNING` または `ERROR` - 問題のみ

### 4. タイムアウトの適切な設定

- 短すぎる: 処理が完了しない
- 長すぎる: コストの増加
- 推奨: 通常の実行時間の2〜3倍

### 5. コールドスタートの最適化

- メモリサイズを増やす（初期化が速くなる）
- Lambda Layersで依存関係を分離
- プロビジョニングされた同時実行を使用（重要な関数）

### 6. モニタリングとアラート

CloudWatch Alarmsで監視：

- エラー率
- 実行時間
- スロットリング
- 同時実行数

## 参考リンク

- [AWS Lambda 公式ドキュメント](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [Lambda ベストプラクティス](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda 料金](https://aws.amazon.com/lambda/pricing/)

## ライセンス

このサンプルコードは学習・教育目的で自由に使用できます。

## サポート

質問や問題がある場合は、issueを作成してください。
