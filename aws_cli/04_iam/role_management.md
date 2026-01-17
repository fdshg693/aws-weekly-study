# IAM ロール管理

## 目次
- [ロールとは](#ロールとは)
- [ロールの作成](#ロールの作成)
- [ロールの一覧表示](#ロールの一覧表示)
- [ロール情報の取得](#ロール情報の取得)
- [ロールの更新](#ロールの更新)
- [ロールの削除](#ロールの削除)
- [信頼ポリシーの管理](#信頼ポリシーの管理)
- [ロールへのポリシーアタッチ](#ロールへのポリシーアタッチ)
- [ロールの引き受け](#ロールの引き受け)
- [インスタンスプロファイル](#インスタンスプロファイル)
- [実践的な例](#実践的な例)

## ロールとは

IAMロールは、特定の権限セットを持つAWSアイデンティティです。ユーザーと異なり、ロールには永続的な認証情報（パスワードやアクセスキー）がありません。代わりに、一時的なセキュリティ認証情報が提供されます。

### ロールの主な用途
- EC2インスタンスへの権限付与
- Lambda関数への権限付与
- クロスアカウントアクセス
- フェデレーテッドユーザーアクセス
- AWSサービス間のアクセス

## ロールの作成

### EC2用ロールの作成
```bash
# 信頼ポリシー（Trust Policy）の作成
cat > trust-policy-ec2.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ロールの作成
aws iam create-role \
  --role-name EC2-S3-Access-Role \
  --assume-role-policy-document file://trust-policy-ec2.json \
  --description "EC2 instance role for S3 access"

# タグ付きでロール作成
aws iam create-role \
  --role-name EC2-S3-Access-Role \
  --assume-role-policy-document file://trust-policy-ec2.json \
  --tags Key=Environment,Value=Production Key=Service,Value=WebServer
```

### Lambda用ロールの作成
```bash
# Lambda用信頼ポリシー
cat > trust-policy-lambda.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ロールの作成
aws iam create-role \
  --role-name Lambda-Execution-Role \
  --assume-role-policy-document file://trust-policy-lambda.json \
  --description "Lambda execution role with CloudWatch Logs access"

# 基本的なLambda実行ポリシーをアタッチ
aws iam attach-role-policy \
  --role-name Lambda-Execution-Role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### クロスアカウントアクセス用ロール
```bash
# クロスアカウント信頼ポリシー
cat > trust-policy-cross-account.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id-12345"
        }
      }
    }
  ]
}
EOF

# ロールの作成
aws iam create-role \
  --role-name CrossAccount-ReadOnly-Role \
  --assume-role-policy-document file://trust-policy-cross-account.json \
  --description "Cross-account read-only access role"
```

### フェデレーション用ロール（SAML）
```bash
# SAML信頼ポリシー
cat > trust-policy-saml.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:saml-provider/ExampleProvider"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF

# ロールの作成
aws iam create-role \
  --role-name SAML-Developer-Role \
  --assume-role-policy-document file://trust-policy-saml.json
```

### 最大セッション期間の設定
```bash
# 12時間（43200秒）のセッション期間でロール作成
aws iam create-role \
  --role-name Extended-Session-Role \
  --assume-role-policy-document file://trust-policy-ec2.json \
  --max-session-duration 43200
```

## ロールの一覧表示

### すべてのロールを表示
```bash
# 基本的な一覧表示
aws iam list-roles

# ロール名のみを表示
aws iam list-roles --query 'Roles[].RoleName' --output table

# ロール名とARNを表示
aws iam list-roles --query 'Roles[].[RoleName,Arn]' --output table

# 作成日順にソート
aws iam list-roles --query 'Roles | sort_by(@, &CreateDate)[].[RoleName,CreateDate]' --output table
```

### パスでフィルタリング
```bash
# 特定パス配下のロールのみ表示
aws iam list-roles --path-prefix /service-role/

# カスタムパスでロール作成と表示
aws iam create-role \
  --role-name MyApp-Role \
  --path /application/myapp/ \
  --assume-role-policy-document file://trust-policy.json

aws iam list-roles --path-prefix /application/
```

### サービスロールのフィルタリング
```bash
# Lambda用ロールのみを抽出
aws iam list-roles \
  --query 'Roles[?contains(AssumeRolePolicyDocument.Statement[0].Principal.Service, `lambda`)].RoleName' \
  --output table

# EC2用ロールのみを抽出
aws iam list-roles \
  --query 'Roles[?contains(AssumeRolePolicyDocument.Statement[0].Principal.Service, `ec2`)].RoleName' \
  --output table
```

## ロール情報の取得

### 詳細情報の取得
```bash
# 特定ロールの情報
aws iam get-role --role-name EC2-S3-Access-Role

# JSONフォーマットで見やすく
aws iam get-role --role-name EC2-S3-Access-Role | jq

# 信頼ポリシーのみを表示
aws iam get-role --role-name EC2-S3-Access-Role \
  --query 'Role.AssumeRolePolicyDocument' | jq
```

### アタッチされたポリシーの確認
```bash
# 管理ポリシーの一覧
aws iam list-attached-role-policies --role-name EC2-S3-Access-Role

# ポリシー名のみを表示
aws iam list-attached-role-policies \
  --role-name EC2-S3-Access-Role \
  --query 'AttachedPolicies[].PolicyName' \
  --output table

# インラインポリシーの一覧
aws iam list-role-policies --role-name EC2-S3-Access-Role
```

### ロールタグの確認
```bash
# ロールのタグを表示
aws iam list-role-tags --role-name EC2-S3-Access-Role

# タグを表形式で表示
aws iam list-role-tags \
  --role-name EC2-S3-Access-Role \
  --query 'Tags[].[Key,Value]' \
  --output table
```

## ロールの更新

### ロール説明の更新
```bash
# 説明を更新
aws iam update-role \
  --role-name EC2-S3-Access-Role \
  --description "Updated: EC2 instance role with S3 and CloudWatch access"
```

### 最大セッション期間の更新
```bash
# 最大セッション期間を変更（1時間 = 3600秒）
aws iam update-role \
  --role-name EC2-S3-Access-Role \
  --max-session-duration 3600

# 最大セッション期間を確認
aws iam get-role \
  --role-name EC2-S3-Access-Role \
  --query 'Role.MaxSessionDuration'
```

## ロールの削除

### 削除前の確認
```bash
#!/bin/bash
ROLE_NAME="$1"

echo "=== Role Information ==="
aws iam get-role --role-name $ROLE_NAME

echo -e "\n=== Attached Policies ==="
aws iam list-attached-role-policies --role-name $ROLE_NAME

echo -e "\n=== Inline Policies ==="
aws iam list-role-policies --role-name $ROLE_NAME

echo -e "\n=== Instance Profiles ==="
aws iam list-instance-profiles-for-role --role-name $ROLE_NAME
```

### 完全な削除スクリプト
```bash
#!/bin/bash
ROLE_NAME="$1"

if [ -z "$ROLE_NAME" ]; then
  echo "Usage: $0 <role-name>"
  exit 1
fi

echo "Deleting role: $ROLE_NAME"

# アタッチされた管理ポリシーをデタッチ
echo "Detaching managed policies..."
for policy_arn in $(aws iam list-attached-role-policies \
  --role-name $ROLE_NAME \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text); do
  echo "  Detaching: $policy_arn"
  aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $policy_arn
done

# インラインポリシーを削除
echo "Deleting inline policies..."
for policy_name in $(aws iam list-role-policies \
  --role-name $ROLE_NAME \
  --query 'PolicyNames[]' \
  --output text); do
  echo "  Deleting: $policy_name"
  aws iam delete-role-policy --role-name $ROLE_NAME --policy-name $policy_name
done

# インスタンスプロファイルから削除
echo "Removing from instance profiles..."
for profile_name in $(aws iam list-instance-profiles-for-role \
  --role-name $ROLE_NAME \
  --query 'InstanceProfiles[].InstanceProfileName' \
  --output text); do
  echo "  Removing from profile: $profile_name"
  aws iam remove-role-from-instance-profile \
    --instance-profile-name $profile_name \
    --role-name $ROLE_NAME
  # インスタンスプロファイルも削除（ロールのみの場合）
  echo "  Deleting profile: $profile_name"
  aws iam delete-instance-profile --instance-profile-name $profile_name 2>/dev/null
done

# ロールを削除
echo "Deleting role..."
aws iam delete-role --role-name $ROLE_NAME

echo "Role $ROLE_NAME has been completely deleted."
```

## 信頼ポリシーの管理

### 信頼ポリシーの更新
```bash
# 新しい信頼ポリシーを作成
cat > new-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# 信頼ポリシーを更新
aws iam update-assume-role-policy \
  --role-name Multi-Service-Role \
  --policy-document file://new-trust-policy.json
```

### MFA条件付き信頼ポリシー
```bash
cat > trust-policy-mfa.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        },
        "NumericLessThan": {
          "aws:MultiFactorAuthAge": "3600"
        }
      }
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name Sensitive-Access-Role \
  --policy-document file://trust-policy-mfa.json
```

### 複数アカウントからのアクセス
```bash
cat > trust-policy-multi-account.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::111111111111:root",
          "arn:aws:iam::222222222222:root",
          "arn:aws:iam::333333333333:root"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name Multi-Account-Access-Role \
  --policy-document file://trust-policy-multi-account.json
```

## ロールへのポリシーアタッチ

### AWS管理ポリシーのアタッチ
```bash
# ReadOnlyAccessをアタッチ
aws iam attach-role-policy \
  --role-name EC2-S3-Access-Role \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# 複数のポリシーをアタッチ
ROLE_NAME="Lambda-Full-Access-Role"
POLICIES=(
  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
)

for policy in "${POLICIES[@]}"; do
  echo "Attaching: $policy"
  aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $policy
done
```

### カスタム管理ポリシーのアタッチ
```bash
# カスタムポリシーをアタッチ
aws iam attach-role-policy \
  --role-name EC2-S3-Access-Role \
  --policy-arn arn:aws:iam::123456789012:policy/CustomS3Policy
```

### インラインポリシーの作成
```bash
# インラインポリシードキュメント
cat > inline-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-app-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::my-app-bucket"
    }
  ]
}
EOF

# インラインポリシーをロールに追加
aws iam put-role-policy \
  --role-name EC2-S3-Access-Role \
  --policy-name S3SpecificBucketAccess \
  --policy-document file://inline-policy.json
```

### ポリシーのデタッチ
```bash
# 管理ポリシーをデタッチ
aws iam detach-role-policy \
  --role-name EC2-S3-Access-Role \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# インラインポリシーを削除
aws iam delete-role-policy \
  --role-name EC2-S3-Access-Role \
  --policy-name S3SpecificBucketAccess
```

## ロールの引き受け

### 基本的なロールの引き受け
```bash
# ロールを引き受ける
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session

# 出力例（一時認証情報）を変数に格納
CREDENTIALS=$(aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session)

# 認証情報を環境変数に設定
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

# ロールの認証情報でコマンド実行
aws s3 ls
```

### ExternalIdを使用したロールの引き受け
```bash
# ExternalIdを指定
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/CrossAccountRole \
  --role-session-name cross-account-session \
  --external-id "unique-external-id-12345"
```

### セッション期間の指定
```bash
# 2時間（7200秒）のセッション
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session \
  --duration-seconds 7200
```

### MFAを使用したロールの引き受け
```bash
# MFAトークンを指定
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/SensitiveRole \
  --role-session-name mfa-session \
  --serial-number arn:aws:iam::123456789012:mfa/user-name \
  --token-code 123456
```

### ロール引き受けスクリプト
```bash
#!/bin/bash
ROLE_ARN="$1"
SESSION_NAME="${2:-cli-session}"
PROFILE_NAME="${3:-assumed-role}"

if [ -z "$ROLE_ARN" ]; then
  echo "Usage: $0 <role-arn> [session-name] [profile-name]"
  exit 1
fi

echo "Assuming role: $ROLE_ARN"
CREDENTIALS=$(aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name $SESSION_NAME)

if [ $? -ne 0 ]; then
  echo "Failed to assume role"
  exit 1
fi

# 認証情報を抽出
ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
SECRET_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')
EXPIRATION=$(echo $CREDENTIALS | jq -r '.Credentials.Expiration')

# プロファイルに設定
aws configure set aws_access_key_id $ACCESS_KEY --profile $PROFILE_NAME
aws configure set aws_secret_access_key $SECRET_KEY --profile $PROFILE_NAME
aws configure set aws_session_token $SESSION_TOKEN --profile $PROFILE_NAME

echo "Role assumed successfully!"
echo "Profile name: $PROFILE_NAME"
echo "Expires at: $EXPIRATION"
echo ""
echo "Usage: aws s3 ls --profile $PROFILE_NAME"
```

## インスタンスプロファイル

### インスタンスプロファイルの作成
```bash
# インスタンスプロファイル作成
aws iam create-instance-profile \
  --instance-profile-name EC2-Instance-Profile

# ロールをインスタンスプロファイルに追加
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-Instance-Profile \
  --role-name EC2-S3-Access-Role
```

### インスタンスプロファイルの一覧表示
```bash
# すべてのインスタンスプロファイルを表示
aws iam list-instance-profiles

# 特定ロールのインスタンスプロファイルを表示
aws iam list-instance-profiles-for-role --role-name EC2-S3-Access-Role
```

### インスタンスプロファイルの情報取得
```bash
# 詳細情報を取得
aws iam get-instance-profile --instance-profile-name EC2-Instance-Profile
```

### EC2インスタンスへの割り当て
```bash
# インスタンス起動時に割り当て
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --iam-instance-profile Name=EC2-Instance-Profile \
  --key-name my-key

# 既存インスタンスに関連付け
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=EC2-Instance-Profile

# 関連付けを解除
aws ec2 disassociate-iam-instance-profile \
  --association-id iip-assoc-12345678

# インスタンスプロファイルを置き換え
aws ec2 replace-iam-instance-profile-association \
  --association-id iip-assoc-12345678 \
  --iam-instance-profile Name=New-Instance-Profile
```

### インスタンスプロファイルの削除
```bash
# ロールを削除
aws iam remove-role-from-instance-profile \
  --instance-profile-name EC2-Instance-Profile \
  --role-name EC2-S3-Access-Role

# インスタンスプロファイルを削除
aws iam delete-instance-profile \
  --instance-profile-name EC2-Instance-Profile
```

## 実践的な例

### 完全なEC2ロールセットアップ
```bash
#!/bin/bash
ROLE_NAME="WebServer-Role"
INSTANCE_PROFILE_NAME="WebServer-Instance-Profile"

# 1. 信頼ポリシーの作成
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# 2. ロールの作成
echo "Creating role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json \
  --description "Web server role with S3 and CloudWatch access"

# 3. ポリシーのアタッチ
echo "Attaching policies..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# 4. カスタムインラインポリシー
cat > custom-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject"],
    "Resource": "arn:aws:s3:::my-log-bucket/*"
  }]
}
EOF

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name CustomS3WriteAccess \
  --policy-document file://custom-policy.json

# 5. インスタンスプロファイルの作成
echo "Creating instance profile..."
aws iam create-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME

# 6. ロールをインスタンスプロファイルに追加
aws iam add-role-to-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --role-name $ROLE_NAME

echo "Setup complete!"
echo "Instance Profile ARN:"
aws iam get-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --query 'InstanceProfile.Arn' \
  --output text
```

### Lambda関数の完全セットアップ
```bash
#!/bin/bash
ROLE_NAME="Lambda-ProcessData-Role"
FUNCTION_NAME="process-data-function"

# 信頼ポリシー
cat > trust-policy-lambda.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# ロール作成
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy-lambda.json

# 基本実行ロール
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# カスタムポリシー（S3とDynamoDB）
cat > lambda-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-data-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/MyTable"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name DataAccessPolicy \
  --policy-document file://lambda-policy.json

# ロールARNを取得
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo "Lambda role created: $ROLE_ARN"
echo "Wait 10 seconds for IAM propagation..."
sleep 10
```

### ロール監査レポート
```bash
#!/bin/bash
OUTPUT_FILE="iam-role-audit-$(date +%Y%m%d).json"

echo "Generating IAM Role Audit Report..."
echo "{"
echo '  "audit_date": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
echo '  "roles": ['

FIRST=true
for role_name in $(aws iam list-roles --query 'Roles[].RoleName' --output text); do
  if [ "$FIRST" = false ]; then
    echo ","
  fi
  FIRST=false
  
  # ロール情報取得
  role_info=$(aws iam get-role --role-name $role_name)
  
  # アタッチされたポリシー
  attached_policies=$(aws iam list-attached-role-policies --role-name $role_name)
  
  # インラインポリシー
  inline_policies=$(aws iam list-role-policies --role-name $role_name)
  
  # インスタンスプロファイル
  instance_profiles=$(aws iam list-instance-profiles-for-role --role-name $role_name 2>/dev/null || echo '{"InstanceProfiles":[]}')
  
  echo "    {"
  echo "      \"role_name\": \"$role_name\","
  echo "      \"role_info\": $role_info,"
  echo "      \"attached_policies\": $attached_policies,"
  echo "      \"inline_policies\": $inline_policies,"
  echo "      \"instance_profiles\": $instance_profiles"
  echo -n "    }"
done

echo ""
echo "  ]"
echo "}"

echo "Audit report generated successfully!"
```

### クロスアカウントロールのセットアップ
```bash
#!/bin/bash
# アカウントA（リソースを持つアカウント）で実行

TRUSTED_ACCOUNT_ID="123456789012"  # アカウントB
EXTERNAL_ID="unique-external-id-$(date +%s)"
ROLE_NAME="CrossAccount-S3-Access"

# 信頼ポリシー
cat > trust-policy-cross.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::${TRUSTED_ACCOUNT_ID}:root"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {"sts:ExternalId": "${EXTERNAL_ID}"}
    }
  }]
}
EOF

# ロール作成
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy-cross.json

# S3アクセスポリシー
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# ロールARN取得
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo "=== Cross-Account Role Setup Complete ==="
echo "Role ARN: $ROLE_ARN"
echo "External ID: $EXTERNAL_ID"
echo ""
echo "Share these values with Account B to assume this role:"
echo ""
echo "aws sts assume-role \\"
echo "  --role-arn $ROLE_ARN \\"
echo "  --role-session-name cross-account-session \\"
echo "  --external-id $EXTERNAL_ID"
```

## ベストプラクティス

### セキュリティ
1. **最小権限の原則**: 必要最小限の権限のみを付与
2. **信頼ポリシーの厳格化**: 必要なプリンシパルのみを許可
3. **ExternalIdの使用**: クロスアカウントアクセスでは必須
4. **MFA条件の追加**: センシティブなリソースへのアクセスには必須
5. **セッション期間の制限**: 必要最小限の時間に設定

### 管理
1. **命名規則の統一**: サービスや用途が分かる名前を使用
2. **タグの活用**: 環境、サービス、コストセンターなどでタグ付け
3. **パスの活用**: 組織構造を反映したパス設計
4. **ドキュメント化**: ロールの目的と権限を文書化
5. **定期的な監査**: 未使用ロールや過剰な権限の確認

### 運用
1. **管理ポリシーの優先**: 可能な限りAWS管理ポリシーを使用
2. **インラインポリシーの制限**: 特殊なケースのみに使用
3. **バージョン管理**: ポリシー変更履歴の記録
4. **テスト環境での検証**: 本番適用前に必ずテスト
5. **アラート設定**: 異常なロール使用を検出

### トラブルシューティング
1. **IAM伝播待機**: ロール作成後は10秒程度待機
2. **信頼ポリシーの確認**: AssumeRole失敗時は最初に確認
3. **CloudTrailログ**: アクセス拒否の詳細な理由を確認
4. **IAM Policy Simulator**: ポリシーのテストに活用
5. **エラーメッセージの活用**: AWSのエラーメッセージは詳細
