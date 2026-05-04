# Lambda + Bedrock + API Key Rotation

## 概要
`terra_prod/lambda` は、**API Gateway HTTP API → Lambda → Amazon Bedrock** の流れを Terraform で構築する独立プロジェクトです。

この構成では、単なる公開 Lambda ではなく、以下をまとめて提供します。

- **Amazon Bedrock を呼び出す API Lambda**
- **`x-api-key` を検証する Lambda Authorizer**
- **Secrets Manager に保存した API キーの自動ローテーション**
- **AWS CLI / Terraform output から API キー情報を追いやすい運用導線**

## 技術スタック
- AWS Lambda（Python 3.12）
- Amazon API Gateway HTTP API
- Amazon Bedrock Runtime
- AWS Secrets Manager
- Lambda Authorizer
- Secrets Manager Rotation Lambda
- Terraform
- IAM Role / Policy
- CloudWatch Logs
- X-Ray（オプション）

## このプロジェクトで作るもの
- `GET /` : 認証済みヘルスチェック
- `POST /` : 認証済み Bedrock 呼び出し API
- `src/lambda_function.py` : Bedrock 本体呼び出し
- `src/authorizer.py` : `x-api-key` 検証
- `src/rotation_lambda.py` : API キー自動ローテーション

## アーキテクチャ

```text
Client
  -> HTTPS + x-api-key
API Gateway HTTP API
  -> Lambda Authorizer (x-api-key validation)
Application Lambda
  -> Amazon Bedrock Runtime

Secrets Manager
  -> stores shared API key
  -> invokes Rotation Lambda automatically
```

## 設計上のポイント
- **Lambda 本体の前段で遮断**: API Gateway Lambda Authorizer が `x-api-key` を検証するため、認証失敗時は本体 Lambda に到達しません。
- **API キーは Secrets Manager 管理**: API キーの参照先は Secrets Manager です。
- **自動ローテーション**: `aws_secretsmanager_secret_rotation` により、定期的にキーを更新できます。
- **運用しやすさ重視**: `terraform output -raw api_key_secret_name` や `make get-api-key` でローカルから取得しやすくしています。
- **Bedrock モデルは変数化**: `bedrock_model_id` を tfvars で切り替え可能です。
- **Authorizer キャッシュをデフォルト無効**: ローテーション後に古いキーを引きずりにくくしています。
- **CORS Origin は変数化**: `cors_allow_origins` で localhost や必要なフロントエンド Origin を明示許可できます。
- **ルート別スロットリング**: `GET /` は秒10、`POST /` は秒4をデフォルトにしています。
- **Bedrock エラーを透過**: Lambda が Bedrock の 429 / 503 などを検知し、構造化した JSON でクライアントへ返します。
- **リクエストログは要約のみ**: Prompt / AI 応答は全文ではなく、先頭10文字と全体文字数だけを CloudWatch Logs に記録します。

## 構成ファイル
- `lambda.tf` - Lambda / Secrets Manager / Rotation 定義
- `api_gateway.tf` - HTTP API / Integration / Authorizer / Route
- `iam.tf` - Application / Authorizer / Rotation の IAM 権限
- `variables.tf` - Bedrock / API key rotation を含む変数定義
- `outputs.tf` - API URL、シークレット名、CLI コマンド例
- `dev.tfvars` / `prod.tfvars` - 環境別設定
- `Makefile` - Terraform / API key / テスト / k6 実行
- `demo-app/` - ローカルのブラウザから API を試すための静的 Web サイト
- `src/lambda_function.py` - Bedrock 呼び出し本体
- `src/authorizer.py` - `x-api-key` 検証
- `src/rotation_lambda.py` - API キーローテーション
- `analyze_request_logs.py` - CloudWatch Logs の要約ログを集計する本体スクリプト
- `analyze_request_logs.sh` - 上記 Python 集計スクリプトを呼ぶ薄いラッパー
- `test_api.sh` - 認証失敗 / 成功系の疎通確認
- `k6_api_test.js` - 認証付き GET / POST の負荷試験

## 前提条件
- Terraform `>= 1.0`
- AWS CLI（認証済み）
- `jq`
- `curl`
- k6（負荷試験を行う場合）
- 対象 AWS アカウントで **Bedrock の利用権限とモデルアクセスが有効** であること

## よく使う操作

### 初期化
```bash
make init
```

### フォーマット / 検証
```bash
make fmt
make validate ENV=dev
```

### plan / apply
```bash
make plan ENV=dev
make apply ENV=dev

make plan ENV=prod
make apply ENV=prod
```

### 出力確認
```bash
make output
terraform output -raw api_invoke_url
terraform output -raw api_key_secret_name
```

## API キー取得

### Makefile から取得
```bash
make get-api-key ENV=dev
```

### AWS CLI から取得
```bash
SECRET_NAME=$(terraform output -raw api_key_secret_name)

aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --query SecretString \
  --output text | jq -r '.api_key // .'
```

## API キーを手動ローテーション

### Makefile から即時ローテーション
```bash
make rotate-secret ENV=dev
```

### AWS CLI から即時ローテーション
```bash
SECRET_NAME=$(terraform output -raw api_key_secret_name)

aws secretsmanager rotate-secret \
  --secret-id "$SECRET_NAME" \
  --rotate-immediately
```

## API テスト

`test_api.sh` は次をまとめて確認します。

1. 認証なしリクエストが拒否される
2. 不正 API キーが拒否される
3. 正しい API キーで `GET /` が成功する
4. 正しい API キーで `POST /` が Bedrock を呼び出す

### 基本実行
```bash
make test ENV=dev
```

### プロンプトを指定して実行
```bash
PROMPT="AWS Lambda を初心者向けに説明してください" make test ENV=dev
```

### API キーや URL を明示して実行
```bash
API_URL="https://xxxx.execute-api.ap-northeast-1.amazonaws.com/" \
API_KEY="your-api-key" \
PROMPT="Bedrock とは何ですか？" \
make test ENV=dev
```

## ローカル用デモ画面

`demo-app/` 配下に、ローカルのブラウザからこの API を簡単に叩くための静的 Web サイトを用意しています。

- `GET /` のヘルスチェックが可能
- `POST /` に Prompt を送って Bedrock 応答を確認可能
- API URL / API Key / Prompt をブラウザに保存可能
- Homebrew で入れた `nginx` 経由で `http://localhost:8080` から配信可能

`file://` で直接 HTML を開く方法はブラウザ制約の影響を受けやすいため、`make demo-app-up` でローカル `nginx` 配信する使い方を推奨します。

詳しい使い方は `demo-app/README.md` を参照してください。

## 負荷試験（k6）

`k6_api_test.js` は、認証付き `GET /` と `POST /` を別シナリオで同時実行し、以下を確認しやすくしています。

- API Gateway のスロットリングによる `429` の発生有無
- 認証付き API の `http_req_duration` p95
- GET ヘルスチェックの成功率
- POST Bedrock 呼び出しの成功率

> 注意: POST は Bedrock 呼び出しを伴うため、**料金が発生**します。まずは低いレートから試してください。

### 基本実行
```bash
make load-test ENV=dev
```

### 軽めの確認
```bash
STAGE_COUNT=1 \
STAGE_DURATION=10s \
make load-test ENV=dev
```

### プロンプトと API 情報を明示
```bash
API_URL="https://xxxx.execute-api.ap-northeast-1.amazonaws.com/" \
API_KEY="your-api-key" \
PROMPT="Amazon Bedrock を一文で説明してください" \
make load-test ENV=prod
```

### さらに細かく調整
```bash
API_URL="https://xxxx.execute-api.ap-northeast-1.amazonaws.com/" \
API_KEY="your-api-key" \
GET_STAGE1_TARGET=5 GET_STAGE2_TARGET=10 GET_STAGE3_TARGET=20 \
POST_STAGE1_TARGET=1 POST_STAGE2_TARGET=2 POST_STAGE3_TARGET=4 \
k6 run ./k6_api_test.js
```

実行結果は `logs/` 配下に保存されます。

- 標準出力ログ: `logs/k6-load-test-YYYYMMDD-HHMMSS.log`
- サマリーJSON: `logs/k6-load-test-YYYYMMDD-HHMMSS-summary.json`

## CloudWatch Logs の要約集計

`src/lambda_function.py` は CloudWatch Logs に以下の要約ログを出します。

- `REQUEST_SUMMARY` - Prompt の先頭10文字と全体文字数
- `RESPONSE_SUMMARY` - AI 応答の先頭10文字と全体文字数
- `ERROR_SUMMARY` - エラー種別・HTTP ステータス・短いエラー要約

そのうえで `analyze_request_logs.sh` を使うと、指定範囲のリクエストについて以下をまとめて確認できます。

- 対象リクエスト数
- エラー件数
- そのうち `429` / `ThrottlingException` / `TooManyRequestsException` による件数
- `stop_reason=max_tokens` によるモデル回答打ち切り件数

### 直近1時間を集計
```bash
make analyze-request-logs ENV=dev
```

### 30分だけ見る
```bash
SINCE=30m make analyze-request-logs ENV=dev
```

### 開始・終了時刻を明示
```bash
START_TIME=2026-05-05T00:00:00Z \
END_TIME=2026-05-05T01:00:00Z \
make analyze-request-logs ENV=prod
```

### GET / POST を切り替える
```bash
METHOD=GET make analyze-request-logs ENV=dev
METHOD=ALL make analyze-request-logs ENV=dev
```

### Terraform output を使わず直接指定
```bash
LOG_GROUP_NAME=/aws/lambda/development-simple-lambda-function \
AWS_REGION=ap-northeast-1 \
SINCE=15m \
METHOD=POST \
bash ./analyze_request_logs.sh
```

## 主要変数
- `bedrock_model_id` - 呼び出す Bedrock モデル ID
- `bedrock_max_tokens` - 最大生成トークン数
- `bedrock_temperature` - temperature
- `cors_allow_origins` - CORS で許可する Origin 一覧（例: `http://localhost:8080`）
- `authorizer_cache_ttl_seconds` - Authorizer 結果キャッシュ秒数
- `api_key_rotation_days` - 自動ローテーション間隔
- `api_key_length` - 生成 API キー長
- `get_route_throttling_rate_limit` - `GET /` の秒間レート上限（デフォルト: 10）
- `post_route_throttling_rate_limit` - `POST /` の秒間レート上限（デフォルト: 4）

## 注意事項
- Lambda コードを変更したら `terraform apply` を実行してください
- Bedrock の利用可否は **リージョン / モデルアクセス設定** に依存します
- API Gateway URL は `terraform output -raw api_invoke_url` で確認できます
- API キーの取得元は Secrets Manager です
- ローテーション直後は、取得済みの古い API キーでは認証に失敗します
- Lambda コード更新後は `terraform apply` しないと、新しい要約ログ形式は反映されません
- Bedrock POST を伴う負荷試験はコストに注意してください
- Bedrock 側でスロットリングや一時障害が起きた場合、API は `429` / `503` などの上流ステータスとエラーコードを JSON で返します
