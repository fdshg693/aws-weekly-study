# AWS CLI 設定ガイド

AWS CLI を使用するための各種設定方法を詳しく解説します。

## 目次
- [aws configure コマンド](#aws-configure-コマンド)
- [名前付きプロファイル](#名前付きプロファイル)
- [環境変数](#環境変数)
- [設定ファイルの構造](#設定ファイルの構造)
- [SSO 設定](#sso-設定)
- [ロールの引き受け（AssumeRole）](#ロールの引き受けassumerole)
- [MFA 設定](#mfa-設定)
- [リージョンと出力形式の設定](#リージョンと出力形式の設定)

---

## aws configure コマンド

AWS CLI を使用する最も基本的な設定方法です。

### 基本的な設定

```bash
# 対話形式で設定を開始
aws configure

# 以下の情報を入力します:
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: ap-northeast-1
# Default output format [None]: json
```

**入力項目の詳細:**

| 項目 | 説明 | 例 |
|------|------|-----|
| AWS Access Key ID | IAM ユーザーのアクセスキー ID | AKIAIOSFODNN7EXAMPLE |
| AWS Secret Access Key | IAM ユーザーのシークレットアクセスキー | wJalrXUtnFEMI/K7MDENG/... |
| Default region name | デフォルトで使用する AWS リージョン | ap-northeast-1 |
| Default output format | コマンド出力の形式 | json, text, table, yaml |

### 個別の設定値を変更

```bash
# 特定の設定値のみを変更
aws configure set aws_access_key_id AKIAIOSFODNN7EXAMPLE
aws configure set aws_secret_access_key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
aws configure set default.region ap-northeast-1
aws configure set default.output json

# 設定値の確認
aws configure get aws_access_key_id
aws configure get default.region
```

### すべての設定を表示

```bash
# 現在の設定を一覧表示
aws configure list

# 出力例:
#       Name                    Value             Type    Location
#       ----                    -----             ----    --------
#    profile                <not set>             None    None
# access_key     ****************MPLE shared-credentials-file
# secret_key     ****************KEY shared-credentials-file
#     region           ap-northeast-1      config-file    ~/.aws/config
```

### プロファイルを指定した設定

```bash
# 特定のプロファイルの設定
aws configure --profile production
aws configure --profile development
aws configure --profile staging

# プロファイルの設定値を確認
aws configure list --profile production
```

### 追加の設定オプション

```bash
# CLI ペジャーの無効化
aws configure set cli_pager ""

# デフォルトのエンドポイント URL（LocalStack など）
aws configure set endpoint_url http://localhost:4566

# タイムアウト設定（秒）
aws configure set cli_connect_timeout 60
aws configure set cli_read_timeout 60

# 最大試行回数
aws configure set max_attempts 3

# リトライモード
aws configure set retry_mode standard
```

---

## 名前付きプロファイル

複数の AWS アカウントや環境を管理するために名前付きプロファイルを使用します。

### プロファイルの作成

```bash
# 本番環境用のプロファイル
aws configure --profile production
# AWS Access Key ID: AKIAI...PROD
# AWS Secret Access Key: wJalr...PROD
# Default region: ap-northeast-1
# Default output format: json

# 開発環境用のプロファイル
aws configure --profile development
# AWS Access Key ID: AKIAI...DEV
# AWS Secret Access Key: wJalr...DEV
# Default region: us-west-2
# Default output format: json

# ステージング環境用のプロファイル
aws configure --profile staging
# AWS Access Key ID: AKIAI...STG
# AWS Secret Access Key: wJalr...STG
# Default region: ap-northeast-1
# Default output format: table
```

### プロファイルの使用

```bash
# プロファイルを指定してコマンドを実行
aws s3 ls --profile production
aws ec2 describe-instances --profile development
aws lambda list-functions --profile staging

# デフォルトプロファイルを環境変数で設定
export AWS_PROFILE=production
aws s3 ls  # production プロファイルが使用される

# 一時的に別のプロファイルを使用
AWS_PROFILE=development aws s3 ls
```

### プロファイルの一覧表示

```bash
# 設定されているプロファイルを確認
aws configure list-profiles

# 出力例:
# default
# production
# development
# staging
```

### プロファイルごとの設定確認

```bash
# 特定のプロファイルの設定を表示
aws configure list --profile production

# すべてのプロファイルの設定を表示
for profile in $(aws configure list-profiles); do
    echo "=== Profile: $profile ==="
    aws configure list --profile $profile
    echo ""
done
```

### プロファイルの削除

```bash
# 設定ファイルから手動で削除
# ~/.aws/credentials と ~/.aws/config を編集

# または sed コマンドで削除（macOS の場合）
sed -i '' '/\[profile development\]/,/^$/d' ~/.aws/config
sed -i '' '/\[development\]/,/^$/d' ~/.aws/credentials

# Linux の場合
sed -i '/\[profile development\]/,/^$/d' ~/.aws/config
sed -i '/\[development\]/,/^$/d' ~/.aws/credentials
```

### 実用例: 環境ごとの使い分け

```bash
# 開発環境でテスト
export AWS_PROFILE=development
aws s3 ls
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"

# 本番環境にデプロイ
export AWS_PROFILE=production
aws s3 cp ./app.zip s3://production-deploy-bucket/
aws lambda update-function-code \
    --function-name my-function \
    --s3-bucket production-deploy-bucket \
    --s3-key app.zip

# スクリプトでの使用
#!/bin/bash
ENVIRONMENT=${1:-development}  # デフォルトは development

export AWS_PROFILE=$ENVIRONMENT
echo "Using profile: $AWS_PROFILE"

aws s3 ls
aws ec2 describe-instances
```

---

## 環境変数

環境変数を使用して AWS CLI の動作を制御できます。

### 認証情報の環境変数

```bash
# アクセスキーとシークレットキー
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# セッショントークン（一時的な認証情報の場合）
export AWS_SESSION_TOKEN=AQoDYXdzEJr...EXAMPLE

# リージョン
export AWS_DEFAULT_REGION=ap-northeast-1

# 出力形式
export AWS_DEFAULT_OUTPUT=json
```

### プロファイル関連の環境変数

```bash
# 使用するプロファイルを指定
export AWS_PROFILE=production

# 設定ファイルのカスタムパス
export AWS_CONFIG_FILE=~/custom/aws/config
export AWS_SHARED_CREDENTIALS_FILE=~/custom/aws/credentials
```

### その他の環境変数

```bash
# CA 証明書バンドル（企業プロキシ環境など）
export AWS_CA_BUNDLE=/path/to/ca-bundle.crt

# エンドポイント URL（LocalStack など）
export AWS_ENDPOINT_URL=http://localhost:4566

# ページャーの無効化
export AWS_PAGER=""

# デバッグモード
export AWS_DEBUG=true

# 最大試行回数
export AWS_MAX_ATTEMPTS=5

# リトライモード（legacy, standard, adaptive）
export AWS_RETRY_MODE=adaptive

# メタデータサービスのタイムアウト（EC2 上での実行時）
export AWS_METADATA_SERVICE_TIMEOUT=5
export AWS_METADATA_SERVICE_NUM_ATTEMPTS=3
```

### 環境変数の優先順位

AWS CLI は以下の順序で認証情報を検索します（上から優先）：

1. コマンドラインオプション（`--region`, `--profile` など）
2. 環境変数（`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` など）
3. CLI 認証情報ファイル（`~/.aws/credentials`）
4. CLI 設定ファイル（`~/.aws/config`）
5. コンテナ認証情報（ECS タスク用）
6. インスタンスプロファイル認証情報（EC2 インスタンス用）

### 実用例: CI/CD での使用

```bash
#!/bin/bash
# CI/CD パイプラインでの使用例

# 環境変数から認証情報を設定（GitHub Actions, GitLab CI など）
export AWS_ACCESS_KEY_ID=$CI_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$CI_AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=ap-northeast-1

# デプロイ実行
aws s3 sync ./build s3://my-website-bucket
aws cloudfront create-invalidation \
    --distribution-id E1234EXAMPLE \
    --paths "/*"
```

**GitHub Actions の例:**
```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
        run: |
          aws s3 sync ./build s3://my-bucket
```

### 環境変数のデバッグ

```bash
# 設定されている AWS 関連の環境変数を表示
env | grep AWS

# または
printenv | grep AWS

# 出力例:
# AWS_PROFILE=production
# AWS_DEFAULT_REGION=ap-northeast-1
# AWS_PAGER=
```

---

## 設定ファイルの構造

AWS CLI は2つの設定ファイルを使用します。

### ファイルの場所

```bash
# Linux/macOS
~/.aws/config          # 設定ファイル
~/.aws/credentials     # 認証情報ファイル

# Windows
%USERPROFILE%\.aws\config
%USERPROFILE%\.aws\credentials
```

### credentials ファイル

認証情報（アクセスキー、シークレットキー）を保存します。

```ini
# ~/.aws/credentials

# デフォルトプロファイル
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# 本番環境
[production]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY

# 開発環境
[development]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY

# セッショントークン付き（一時認証情報）
[temporary]
aws_access_key_id = ASIATEMP123EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
aws_session_token = AQoDYXdzEJr1K...EXAMPLETOKEN
```

### config ファイル

リージョン、出力形式、その他の設定を保存します。

```ini
# ~/.aws/config

# デフォルトプロファイル
[default]
region = ap-northeast-1
output = json

# 本番環境
[profile production]
region = ap-northeast-1
output = json
cli_pager = 

# 開発環境
[profile development]
region = us-west-2
output = table
cli_pager = 

# ステージング環境（MFA 必須）
[profile staging]
region = ap-northeast-1
output = json
mfa_serial = arn:aws:iam::123456789012:mfa/user-name

# ロールを使用するプロファイル
[profile admin]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = default
region = ap-northeast-1
output = json

# 複数の設定を含むプロファイル
[profile comprehensive]
region = ap-northeast-1
output = json
cli_pager = 
cli_auto_prompt = on-partial
cli_connect_timeout = 60
cli_read_timeout = 60
max_attempts = 3
retry_mode = adaptive
s3 =
    max_concurrent_requests = 20
    max_queue_size = 10000
    multipart_threshold = 64MB
    multipart_chunksize = 16MB
```

### ファイルのパーミッション設定

セキュリティのため、認証情報ファイルのパーミッションを制限します。

```bash
# 所有者のみが読み書きできるように設定
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# ディレクトリのパーミッション
chmod 700 ~/.aws

# 確認
ls -la ~/.aws/
# drwx------   4 username  staff   128 Nov 15 10:00 .
# -rw-------   1 username  staff   234 Nov 15 10:00 credentials
# -rw-------   1 username  staff   567 Nov 15 10:00 config
```

### 設定ファイルの編集

```bash
# テキストエディタで直接編集
vim ~/.aws/credentials
vim ~/.aws/config

# または
nano ~/.aws/credentials
code ~/.aws/credentials  # VS Code

# 設定の検証
aws configure list
aws sts get-caller-identity
```

### 複数アカウントの管理例

```ini
# ~/.aws/config
[default]
region = ap-northeast-1
output = json

# 個人アカウント
[profile personal]
region = us-east-1
output = json

# 会社アカウント - 開発
[profile company-dev]
region = ap-northeast-1
output = json
role_arn = arn:aws:iam::111111111111:role/DeveloperRole
source_profile = company-base
mfa_serial = arn:aws:iam::111111111111:mfa/your-username

# 会社アカウント - 本番
[profile company-prod]
region = ap-northeast-1
output = json
role_arn = arn:aws:iam::222222222222:role/AdminRole
source_profile = company-base
mfa_serial = arn:aws:iam::222222222222:mfa/your-username
duration_seconds = 3600

# 会社アカウント - ベースプロファイル
[profile company-base]
region = ap-northeast-1
output = json
```

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAI...DEFAULT
aws_secret_access_key = wJalr...DEFAULT

[personal]
aws_access_key_id = AKIAI...PERSONAL
aws_secret_access_key = wJalr...PERSONAL

[company-base]
aws_access_key_id = AKIAI...COMPANY
aws_secret_access_key = wJalr...COMPANY
```

---

## SSO 設定

AWS Single Sign-On (AWS IAM Identity Center) を使用した設定方法です。

### SSO の初期設定

```bash
# SSO セッションの設定
aws configure sso

# 対話形式で以下を入力:
# SSO session name: my-sso
# SSO start URL: https://my-sso-portal.awsapps.com/start
# SSO region: ap-northeast-1
# SSO registration scopes: sso:account:access
# 
# ブラウザが開き、SSO ログインを行います
# 
# アカウント選択画面でアカウントを選択
# ロールを選択（例: AdministratorAccess）
# CLI default client Region: ap-northeast-1
# CLI default output format: json
# CLI profile name: my-sso-profile
```

### config ファイルでの SSO 設定

```ini
# ~/.aws/config

# SSO セッションの定義
[sso-session my-sso]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access

# SSO プロファイル（開発環境）
[profile sso-dev]
sso_session = my-sso
sso_account_id = 111111111111
sso_role_name = DeveloperAccess
region = ap-northeast-1
output = json

# SSO プロファイル（本番環境）
[profile sso-prod]
sso_session = my-sso
sso_account_id = 222222222222
sso_role_name = ReadOnlyAccess
region = ap-northeast-1
output = json

# レガシー SSO 設定（AWS CLI v2.0 以前）
[profile legacy-sso]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = ap-northeast-1
output = json
```

### SSO ログイン

```bash
# SSO セッションにログイン
aws sso login --profile sso-dev

# または SSO セッション名を指定
aws sso login --sso-session my-sso

# ブラウザが開き、認証を求められます
# 認証後、ターミナルに戻って作業を継続

# ログイン状態の確認
aws sts get-caller-identity --profile sso-dev
```

### SSO ログアウト

```bash
# 特定のプロファイルからログアウト
aws sso logout --profile sso-dev

# すべての SSO セッションからログアウト
aws sso logout
```

### SSO セッションの有効期限

```bash
# セッションの有効期限を設定（秒単位、最大12時間）
# config ファイルに追加
[sso-session my-sso]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access
sso_max_attempts = 3
sso_session_max_age_minutes = 720  # 12時間
```

### 複数組織の SSO 管理

```ini
# ~/.aws/config

# 組織A の SSO
[sso-session org-a]
sso_start_url = https://org-a.awsapps.com/start
sso_region = ap-northeast-1

[profile org-a-dev]
sso_session = org-a
sso_account_id = 111111111111
sso_role_name = Developer
region = ap-northeast-1

[profile org-a-prod]
sso_session = org-a
sso_account_id = 222222222222
sso_role_name = ReadOnly
region = ap-northeast-1

# 組織B の SSO
[sso-session org-b]
sso_start_url = https://org-b.awsapps.com/start
sso_region = us-east-1

[profile org-b-dev]
sso_session = org-b
sso_account_id = 333333333333
sso_role_name = PowerUser
region = us-east-1
```

### SSO を使用したスクリプト例

```bash
#!/bin/bash
# SSO 認証を使用したデプロイスクリプト

PROFILE="sso-prod"

# SSO ログイン状態を確認
if ! aws sts get-caller-identity --profile $PROFILE &>/dev/null; then
    echo "SSO ログインが必要です..."
    aws sso login --profile $PROFILE
fi

# 認証後、AWS コマンドを実行
echo "デプロイを開始します..."
aws s3 sync ./build s3://production-bucket --profile $PROFILE
aws cloudfront create-invalidation \
    --distribution-id E1234EXAMPLE \
    --paths "/*" \
    --profile $PROFILE

echo "デプロイ完了"
```

---

## ロールの引き受け（AssumeRole）

IAM ロールを使用して、異なるアカウントやより高い権限でコマンドを実行します。

### 基本的なロール設定

```ini
# ~/.aws/config

# ベースとなるプロファイル
[profile base]
region = ap-northeast-1
output = json

# ロールを引き受けるプロファイル
[profile admin]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = base
region = ap-northeast-1
output = json
```

```ini
# ~/.aws/credentials

[base]
aws_access_key_id = AKIAI...BASE
aws_secret_access_key = wJalr...BASE
```

### クロスアカウント ロール

```ini
# ~/.aws/config

# アカウント A（ベース）
[profile account-a]
region = ap-northeast-1
output = json

# アカウント B のロールを引き受ける
[profile account-b-admin]
role_arn = arn:aws:iam::999999999999:role/CrossAccountAdmin
source_profile = account-a
region = ap-northeast-1
external_id = unique-external-id-12345
```

### MFA 付きロール

```ini
# ~/.aws/config

[profile mfa-admin]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = default
mfa_serial = arn:aws:iam::123456789012:mfa/user-name
region = ap-northeast-1
```

```bash
# MFA トークンを入力してロールを引き受ける
aws sts assume-role \
    --role-arn arn:aws:iam::123456789012:role/AdminRole \
    --role-session-name my-session \
    --serial-number arn:aws:iam::123456789012:mfa/user-name \
    --token-code 123456

# 出力から認証情報を取得して環境変数に設定
```

### ロールセッションの有効期限設定

```ini
# ~/.aws/config

[profile long-session]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = default
duration_seconds = 43200  # 12時間（最大値）
region = ap-northeast-1
```

### ロールチェーン

複数のロールを連鎖的に引き受けることができます。

```ini
# ~/.aws/config

# レベル1: ベースプロファイル
[profile base]
region = ap-northeast-1

# レベル2: 最初のロール
[profile role-level1]
role_arn = arn:aws:iam::111111111111:role/Level1Role
source_profile = base
region = ap-northeast-1

# レベル3: 2番目のロール
[profile role-level2]
role_arn = arn:aws:iam::222222222222:role/Level2Role
source_profile = role-level1
region = ap-northeast-1
```

### 実用例: マルチアカウント管理

```bash
#!/bin/bash
# 複数アカウントのリソースを確認するスクリプト

ACCOUNTS=("dev" "staging" "production")

for account in "${ACCOUNTS[@]}"; do
    echo "=== Account: $account ==="
    
    # ロールを引き受けて S3 バケットを一覧表示
    aws s3 ls --profile "$account-admin"
    
    # EC2 インスタンスを確認
    aws ec2 describe-instances \
        --profile "$account-admin" \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    echo ""
done
```

### 一時認証情報の手動取得

```bash
# ロールを引き受けて一時認証情報を取得
aws sts assume-role \
    --role-arn arn:aws:iam::123456789012:role/MyRole \
    --role-session-name my-session-$(date +%s) \
    --duration-seconds 3600

# JSON 出力から認証情報を抽出（jq 使用）
OUTPUT=$(aws sts assume-role \
    --role-arn arn:aws:iam::123456789012:role/MyRole \
    --role-session-name my-session)

export AWS_ACCESS_KEY_ID=$(echo $OUTPUT | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $OUTPUT | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $OUTPUT | jq -r '.Credentials.SessionToken')

# これで AWS コマンドを実行できます
aws s3 ls
```

---

## MFA 設定

Multi-Factor Authentication (MFA) を使用したセキュアな認証設定です。

### MFA デバイスの登録

```bash
# 仮想 MFA デバイスの作成
aws iam create-virtual-mfa-device \
    --virtual-mfa-device-name my-mfa-device \
    --outfile QRCode.png \
    --bootstrap-method QRCodePNG

# ユーザーに MFA デバイスを関連付け
aws iam enable-mfa-device \
    --user-name my-user \
    --serial-number arn:aws:iam::123456789012:mfa/my-mfa-device \
    --authentication-code1 123456 \
    --authentication-code2 789012
```

### MFA を使用したプロファイル設定

```ini
# ~/.aws/config

[profile mfa-user]
region = ap-northeast-1
output = json
mfa_serial = arn:aws:iam::123456789012:mfa/my-user

# MFA 付きでロールを引き受ける
[profile mfa-admin]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = default
mfa_serial = arn:aws:iam::123456789012:mfa/my-user
region = ap-northeast-1
duration_seconds = 3600
```

### MFA トークンを使用したコマンド実行

```bash
# MFA が必要なコマンドを実行
aws s3 ls --profile mfa-admin

# プロンプトで MFA トークンを入力
# Enter MFA code for arn:aws:iam::123456789012:mfa/my-user: 123456
```

### MFA セッショントークンの取得

```bash
# セッショントークンを取得
aws sts get-session-token \
    --serial-number arn:aws:iam::123456789012:mfa/my-user \
    --token-code 123456 \
    --duration-seconds 129600

# 出力例:
# {
#     "Credentials": {
#         "AccessKeyId": "ASIATEMP123EXAMPLE",
#         "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
#         "SessionToken": "AQoDYXdzEJr...",
#         "Expiration": "2024-11-16T10:00:00Z"
#     }
# }
```

### MFA セッション管理スクリプト

```bash
#!/bin/bash
# MFA セッショントークンを取得して環境変数に設定

MFA_SERIAL="arn:aws:iam::123456789012:mfa/my-user"
DURATION=43200  # 12時間

# MFA トークンを入力
read -p "Enter MFA token: " MFA_TOKEN

# セッショントークンを取得
OUTPUT=$(aws sts get-session-token \
    --serial-number $MFA_SERIAL \
    --token-code $MFA_TOKEN \
    --duration-seconds $DURATION)

# 環境変数に設定
export AWS_ACCESS_KEY_ID=$(echo $OUTPUT | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $OUTPUT | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $OUTPUT | jq -r '.Credentials.SessionToken')

echo "MFA セッションが設定されました"
echo "有効期限: $(echo $OUTPUT | jq -r '.Credentials.Expiration')"

# 確認
aws sts get-caller-identity
```

### MFA セッションの自動更新

```bash
#!/bin/bash
# MFA セッションを自動的に更新するスクリプト

MFA_SERIAL="arn:aws:iam::123456789012:mfa/my-user"
CREDENTIALS_FILE="$HOME/.aws/mfa_credentials"
DURATION=43200

# 既存のセッションを確認
if [ -f "$CREDENTIALS_FILE" ]; then
    source "$CREDENTIALS_FILE"
    
    # 有効期限を確認
    if aws sts get-caller-identity &>/dev/null; then
        echo "既存の MFA セッションが有効です"
        exit 0
    fi
fi

# 新しいセッションを取得
read -p "Enter MFA token: " MFA_TOKEN

OUTPUT=$(aws sts get-session-token \
    --serial-number $MFA_SERIAL \
    --token-code $MFA_TOKEN \
    --duration-seconds $DURATION)

# 認証情報をファイルに保存
cat > "$CREDENTIALS_FILE" <<EOF
export AWS_ACCESS_KEY_ID=$(echo $OUTPUT | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $OUTPUT | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $OUTPUT | jq -r '.Credentials.SessionToken')
EOF

chmod 600 "$CREDENTIALS_FILE"

echo "MFA セッションを更新しました"
echo "次回は 'source $CREDENTIALS_FILE' で読み込めます"
```

---

## リージョンと出力形式の設定

### リージョンの設定

```bash
# デフォルトリージョンの設定
aws configure set region ap-northeast-1

# プロファイルごとのリージョン設定
aws configure set region us-east-1 --profile production
aws configure set region ap-northeast-1 --profile development

# コマンド実行時にリージョンを指定
aws ec2 describe-instances --region ap-northeast-1
aws s3 ls --region us-west-2
```

**主要なリージョンコード:**
```bash
# 日本
ap-northeast-1  # 東京
ap-northeast-3  # 大阪

# アメリカ
us-east-1       # バージニア北部
us-east-2       # オハイオ
us-west-1       # カリフォルニア北部
us-west-2       # オレゴン

# ヨーロッパ
eu-west-1       # アイルランド
eu-central-1    # フランクフルト

# アジアパシフィック
ap-southeast-1  # シンガポール
ap-southeast-2  # シドニー
ap-south-1      # ムンバイ
```

### 出力形式の設定

AWS CLI は4つの出力形式をサポートしています。

#### 1. JSON（デフォルト）

```bash
# JSON 形式で出力
aws ec2 describe-instances --output json

# 設定
aws configure set output json
```

**特徴:**
- 最も詳細な情報
- プログラムでの解析が容易
- jq コマンドと組み合わせて使用

#### 2. Table

```bash
# テーブル形式で出力
aws ec2 describe-instances --output table

# 設定
aws configure set output table
```

**特徴:**
- 人間が読みやすい
- ターミナルでの確認に最適
- 大量のデータには不向き

#### 3. Text

```bash
# テキスト形式で出力
aws ec2 describe-instances --output text

# 設定
aws configure set output text
```

**特徴:**
- タブ区切り
- スクリプトでの解析に便利
- grep, awk などと組み合わせて使用

#### 4. YAML

```bash
# YAML 形式で出力
aws ec2 describe-instances --output yaml

# 設定
aws configure set output yaml
```

**特徴:**
- 読みやすい階層構造
- CloudFormation テンプレートとの親和性が高い

### 出力形式の実例比較

```bash
# JSON
aws ec2 describe-instances --output json --query 'Reservations[0].Instances[0].InstanceId'
# "i-1234567890abcdef0"

# Table
aws ec2 describe-instances --output table --query 'Reservations[].Instances[].[InstanceId,State.Name]'
# ----------------------------
# |   DescribeInstances     |
# +-----------+-------------+
# |  i-12345  |  running   |
# +-----------+-------------+

# Text
aws ec2 describe-instances --output text --query 'Reservations[].Instances[].[InstanceId,State.Name]'
# i-1234567890abcdef0    running

# YAML
aws ec2 describe-instances --output yaml --query 'Reservations[0].Instances[0].InstanceId'
# i-1234567890abcdef0
```

### プロファイルごとの出力形式設定

```ini
# ~/.aws/config

[profile production]
region = ap-northeast-1
output = json

[profile development]
region = us-west-2
output = table

[profile ci-cd]
region = ap-northeast-1
output = text
```

### 用途別の推奨設定

```bash
# 開発・デバッグ: JSON
aws configure set output json --profile development

# 手動確認: Table
aws configure set output table --profile interactive

# スクリプト: Text
aws configure set output text --profile automation

# Infrastructure as Code: YAML
aws configure set output yaml --profile iac
```

---

## 設定のベストプラクティス

### 1. セキュリティ

```bash
# 認証情報ファイルのパーミッションを制限
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# 認証情報をバージョン管理に含めない
echo ".aws/" >> .gitignore

# IAM ロールを使用（EC2, ECS, Lambda など）
# アクセスキーの使用を最小限に抑える
```

### 2. 組織的な管理

```bash
# プロファイル名に命名規則を適用
# 例: {organization}-{environment}-{role}
# company-prod-readonly
# company-dev-admin
# personal-test

# 環境変数でデフォルトプロファイルを設定
export AWS_PROFILE=company-dev-admin
```

### 3. 設定の検証

```bash
# 現在の設定を確認
aws configure list

# 認証情報のテスト
aws sts get-caller-identity

# 各プロファイルの動作確認
for profile in $(aws configure list-profiles); do
    echo "Testing profile: $profile"
    aws sts get-caller-identity --profile $profile || echo "Failed"
done
```

### 4. ドキュメント化

```bash
# チーム用のREADMEを作成
cat > AWS_SETUP.md <<'EOF'
# AWS CLI セットアップガイド

## 必要なプロファイル

- `company-dev`: 開発環境（全権限）
- `company-staging`: ステージング環境（読み取り専用）
- `company-prod`: 本番環境（デプロイ権限のみ）

## セットアップ手順

1. AWS CLI のインストール
2. SSO 設定: `aws configure sso`
3. プロファイルの確認: `aws configure list-profiles`

## 使用例

```bash
# 開発環境
export AWS_PROFILE=company-dev
aws s3 ls

# 本番環境にデプロイ
aws s3 sync ./build s3://prod-bucket --profile company-prod
```
EOF
```

---

## まとめ

- `aws configure` で基本設定を実施
- 名前付きプロファイルで複数環境を管理
- 環境変数で柔軟な設定が可能
- SSO を使用してセキュアな認証を実現
- MFA で多要素認証を強化
- 用途に応じた出力形式を選択

次は [general_options.md](general_options.md) で AWS CLI の汎用オプションを学びましょう。
