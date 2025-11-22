# IAM ポリシー操作

## 目次
- [ポリシーとは](#ポリシーとは)
- [管理ポリシーの作成](#管理ポリシーの作成)
- [ポリシーの一覧表示](#ポリシーの一覧表示)
- [ポリシー情報の取得](#ポリシー情報の取得)
- [ポリシーバージョンの管理](#ポリシーバージョンの管理)
- [ポリシーのアタッチ/デタッチ](#ポリシーのアタッチデタッチ)
- [ポリシーの削除](#ポリシーの削除)
- [ポリシーシミュレーター](#ポリシーシミュレーター)
- [ポリシーのベストプラクティス](#ポリシーのベストプラクティス)

## ポリシーとは

IAMポリシーは、AWSリソースへのアクセス権限を定義するJSON形式のドキュメントです。

### ポリシーの種類
- **AWS管理ポリシー**: AWSが提供・管理
- **カスタマー管理ポリシー**: ユーザーが作成・管理
- **インラインポリシー**: ユーザー/ロール/グループに直接埋め込み

## 管理ポリシーの作成

### 基本的なポリシー作成
```bash
# S3読み取り専用ポリシー
cat > s3-readonly-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
EOF

# ポリシーを作成
aws iam create-policy \
  --policy-name S3ReadOnlyCustomPolicy \
  --policy-document file://s3-readonly-policy.json \
  --description "Custom S3 read-only access to specific bucket"
```

### 複雑なポリシーの作成
```bash
# マルチサービスアクセスポリシー
cat > multi-service-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3FullAccessToSpecificBucket",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::myapp-bucket",
        "arn:aws:s3:::myapp-bucket/*"
      ]
    },
    {
      "Sid": "DynamoDBReadWrite",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/MyTable"
    },
    {
      "Sid": "CloudWatchLogsWrite",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Sid": "SNSPublish",
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:*:*:MyTopic"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name AppBackendPolicy \
  --policy-document file://multi-service-policy.json \
  --description "Backend application policy with multi-service access"
```

### 条件付きポリシー
```bash
# IP制限付きポリシー
cat > ip-restricted-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "203.0.113.0/24",
            "198.51.100.0/24"
          ]
        }
      }
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name S3AccessFromOfficeOnly \
  --policy-document file://ip-restricted-policy.json
```

```bash
# 時間制限付きポリシー
cat > time-restricted-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {
        "DateGreaterThan": {"aws:CurrentTime": "2024-01-01T00:00:00Z"},
        "DateLessThan": {"aws:CurrentTime": "2024-12-31T23:59:59Z"}
      }
    }
  ]
}
EOF
```

```bash
# MFA必須ポリシー
cat > mfa-required-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {
        "Bool": {"aws:MultiFactorAuthPresent": "true"}
      }
    }
  ]
}
EOF
```

### タグベースのポリシー
```bash
# リソースタグに基づくアクセス制御
cat > tag-based-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:RebootInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Environment": "Development",
          "ec2:ResourceTag/Team": "${aws:username}"
        }
      }
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name EC2DevEnvironmentAccess \
  --policy-document file://tag-based-policy.json
```

## ポリシーの一覧表示

### すべてのポリシーを表示
```bash
# カスタマー管理ポリシーのみ
aws iam list-policies --scope Local

# AWS管理ポリシーのみ
aws iam list-policies --scope AWS

# すべてのポリシー
aws iam list-policies --scope All

# ポリシー名とARNのみ表示
aws iam list-policies --scope Local \
  --query 'Policies[].[PolicyName,Arn]' \
  --output table
```

### アタッチされているポリシーのみ表示
```bash
# アタッチされているカスタマー管理ポリシー
aws iam list-policies \
  --scope Local \
  --only-attached \
  --query 'Policies[].[PolicyName,AttachmentCount]' \
  --output table
```

### パスでフィルタリング
```bash
# 特定パス配下のポリシー
aws iam list-policies \
  --scope Local \
  --path-prefix /application/

# ポリシー作成時にパスを指定
aws iam create-policy \
  --policy-name MyAppPolicy \
  --path /application/myapp/ \
  --policy-document file://policy.json
```

## ポリシー情報の取得

### ポリシーの詳細情報
```bash
# ポリシーのメタデータ
aws iam get-policy \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy

# 特定バージョンのポリシードキュメント
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy \
  --version-id v1

# デフォルトバージョンのポリシードキュメントを取得
POLICY_ARN="arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy"
DEFAULT_VERSION=$(aws iam get-policy --policy-arn $POLICY_ARN --query 'Policy.DefaultVersionId' --output text)
aws iam get-policy-version --policy-arn $POLICY_ARN --version-id $DEFAULT_VERSION
```

### ポリシードキュメントをファイルに保存
```bash
#!/bin/bash
POLICY_ARN="$1"
OUTPUT_FILE="policy-backup-$(date +%Y%m%d-%H%M%S).json"

# デフォルトバージョンを取得
DEFAULT_VERSION=$(aws iam get-policy --policy-arn $POLICY_ARN --query 'Policy.DefaultVersionId' --output text)

# ポリシードキュメントを保存
aws iam get-policy-version \
  --policy-arn $POLICY_ARN \
  --version-id $DEFAULT_VERSION \
  --query 'PolicyVersion.Document' > $OUTPUT_FILE

echo "Policy document saved to: $OUTPUT_FILE"
```

### ポリシーのアタッチ状況確認
```bash
# ポリシーがアタッチされているエンティティを確認
POLICY_ARN="arn:aws:iam::123456789012:policy/MyPolicy"

echo "=== Users ==="
aws iam list-entities-for-policy \
  --policy-arn $POLICY_ARN \
  --entity-filter User \
  --query 'PolicyUsers[].UserName'

echo "=== Roles ==="
aws iam list-entities-for-policy \
  --policy-arn $POLICY_ARN \
  --entity-filter Role \
  --query 'PolicyRoles[].RoleName'

echo "=== Groups ==="
aws iam list-entities-for-policy \
  --policy-arn $POLICY_ARN \
  --entity-filter Group \
  --query 'PolicyGroups[].GroupName'
```

## ポリシーバージョンの管理

### 新しいバージョンの作成
```bash
# ポリシーを更新（新しいバージョンを作成）
cat > updated-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
EOF

# 新しいバージョンを作成しデフォルトに設定
aws iam create-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy \
  --policy-document file://updated-policy.json \
  --set-as-default
```

### バージョンの一覧表示
```bash
# すべてのバージョンを表示
aws iam list-policy-versions \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy

# バージョン情報を見やすく表示
aws iam list-policy-versions \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy \
  --query 'Versions[].[VersionId,IsDefaultVersion,CreateDate]' \
  --output table
```

### デフォルトバージョンの変更
```bash
# 特定バージョンをデフォルトに設定
aws iam set-default-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy \
  --version-id v2
```

### 古いバージョンの削除
```bash
# 特定バージョンを削除
aws iam delete-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy \
  --version-id v1

# 古いバージョンを一括削除（デフォルト以外）
POLICY_ARN="arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy"
for version in $(aws iam list-policy-versions \
  --policy-arn $POLICY_ARN \
  --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
  --output text); do
  echo "Deleting version: $version"
  aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $version
done
```

## ポリシーのアタッチ/デタッチ

### ユーザーへのアタッチ
```bash
# ポリシーをユーザーにアタッチ
aws iam attach-user-policy \
  --user-name john-doe \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy

# 複数のポリシーをアタッチ
POLICIES=(
  "arn:aws:iam::123456789012:policy/Policy1"
  "arn:aws:iam::123456789012:policy/Policy2"
  "arn:aws:iam::123456789012:policy/Policy3"
)

for policy in "${POLICIES[@]}"; do
  aws iam attach-user-policy --user-name john-doe --policy-arn $policy
done
```

### グループへのアタッチ
```bash
# ポリシーをグループにアタッチ
aws iam attach-group-policy \
  --group-name developers \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy
```

### ロールへのアタッチ
```bash
# ポリシーをロールにアタッチ
aws iam attach-role-policy \
  --role-name EC2-Application-Role \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy
```

### デタッチ
```bash
# ユーザーからデタッチ
aws iam detach-user-policy \
  --user-name john-doe \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy

# グループからデタッチ
aws iam detach-group-policy \
  --group-name developers \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy

# ロールからデタッチ
aws iam detach-role-policy \
  --role-name EC2-Application-Role \
  --policy-arn arn:aws:iam::123456789012:policy/S3ReadOnlyCustomPolicy
```

## ポリシーの削除

### 削除前の確認
```bash
#!/bin/bash
POLICY_ARN="$1"

echo "=== Policy Information ==="
aws iam get-policy --policy-arn $POLICY_ARN

echo -e "\n=== Attached Entities ==="
aws iam list-entities-for-policy --policy-arn $POLICY_ARN

echo -e "\n=== All Versions ==="
aws iam list-policy-versions --policy-arn $POLICY_ARN
```

### 完全な削除スクリプト
```bash
#!/bin/bash
POLICY_ARN="$1"

if [ -z "$POLICY_ARN" ]; then
  echo "Usage: $0 <policy-arn>"
  exit 1
fi

echo "Deleting policy: $POLICY_ARN"

# すべてのエンティティからデタッチ
echo "Detaching from users..."
for user in $(aws iam list-entities-for-policy --policy-arn $POLICY_ARN --entity-filter User --query 'PolicyUsers[].UserName' --output text); do
  echo "  Detaching from user: $user"
  aws iam detach-user-policy --user-name $user --policy-arn $POLICY_ARN
done

echo "Detaching from groups..."
for group in $(aws iam list-entities-for-policy --policy-arn $POLICY_ARN --entity-filter Group --query 'PolicyGroups[].GroupName' --output text); do
  echo "  Detaching from group: $group"
  aws iam detach-group-policy --group-name $group --policy-arn $POLICY_ARN
done

echo "Detaching from roles..."
for role in $(aws iam list-entities-for-policy --policy-arn $POLICY_ARN --entity-filter Role --query 'PolicyRoles[].RoleName' --output text); do
  echo "  Detaching from role: $role"
  aws iam detach-role-policy --role-name $role --policy-arn $POLICY_ARN
done

# 非デフォルトバージョンを削除
echo "Deleting non-default versions..."
for version in $(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text); do
  echo "  Deleting version: $version"
  aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $version
done

# ポリシーを削除
echo "Deleting policy..."
aws iam delete-policy --policy-arn $POLICY_ARN

echo "Policy deleted successfully!"
```

## ポリシーシミュレーター

### ユーザーアクションのシミュレーション
```bash
# ユーザーが特定のアクションを実行できるかテスト
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/john-doe \
  --action-names s3:GetObject s3:PutObject \
  --resource-arns arn:aws:s3:::my-bucket/file.txt

# 複数のアクションをテスト
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/john-doe \
  --action-names \
    s3:GetObject \
    s3:PutObject \
    s3:DeleteObject \
    s3:ListBucket \
  --resource-arns \
    arn:aws:s3:::my-bucket \
    arn:aws:s3:::my-bucket/*
```

### カスタムポリシーのシミュレーション
```bash
# ポリシードキュメントを直接テスト
aws iam simulate-custom-policy \
  --policy-input-list file://test-policy.json \
  --action-names s3:GetObject ec2:DescribeInstances \
  --resource-arns \
    arn:aws:s3:::my-bucket/* \
    arn:aws:ec2:*:*:instance/*

# 結果をわかりやすく表示
aws iam simulate-custom-policy \
  --policy-input-list file://test-policy.json \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/* \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' \
  --output table
```

### 条件付きシミュレーション
```bash
# IP制限をシミュレート
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/john-doe \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/* \
  --context-entries \
    "ContextKeyName=aws:SourceIp,ContextKeyValues=203.0.113.5,ContextKeyType=ip"

# MFA条件をシミュレート
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/john-doe \
  --action-names ec2:TerminateInstances \
  --resource-arns arn:aws:ec2:*:*:instance/* \
  --context-entries \
    "ContextKeyName=aws:MultiFactorAuthPresent,ContextKeyValues=true,ContextKeyType=boolean"
```

## ポリシーのベストプラクティス

### 1. 最小権限の原則
```bash
# 悪い例：過剰な権限
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}

# 良い例：必要最小限の権限
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::specific-bucket/specific-prefix/*"
}
```

### 2. 明示的なDeny
```bash
# 重要リソースへのアクセスを明示的に拒否
cat > explicit-deny-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "s3:DeleteBucket",
      "Resource": "arn:aws:s3:::production-*"
    }
  ]
}
EOF
```

### 3. 条件の活用
```bash
# セキュアな通信の強制
cat > secure-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*",
      "Condition": {
        "Bool": {"aws:SecureTransport": "true"}
      }
    }
  ]
}
EOF
```

### 4. リソースの具体的指定
```bash
# 特定リソースのみにアクセス許可
cat > specific-resource-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": [
        "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable",
        "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/index/*"
      ]
    }
  ]
}
EOF
```

### 5. Sidの使用
```bash
# 各ステートメントにわかりやすいSidを付与
cat > well-documented-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadFromAppBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::myapp-bucket",
        "arn:aws:s3:::myapp-bucket/*"
      ]
    },
    {
      "Sid": "AllowDynamoDBReadWrite",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/MyTable"
    },
    {
      "Sid": "DenyDeletionOfProductionResources",
      "Effect": "Deny",
      "Action": ["*:Delete*", "*:Terminate*"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Environment": "Production"
        }
      }
    }
  ]
}
EOF
```

### ポリシー検証スクリプト
```bash
#!/bin/bash
# ポリシー構文の検証

POLICY_FILE="$1"

if [ ! -f "$POLICY_FILE" ]; then
  echo "File not found: $POLICY_FILE"
  exit 1
fi

# JSON構文チェック
if ! jq empty "$POLICY_FILE" 2>/dev/null; then
  echo "❌ Invalid JSON syntax"
  exit 1
fi

echo "✅ Valid JSON syntax"

# Version check
VERSION=$(jq -r '.Version' "$POLICY_FILE")
if [ "$VERSION" != "2012-10-17" ]; then
  echo "⚠️  Warning: Policy version should be '2012-10-17'"
fi

# Statement check
STATEMENT_COUNT=$(jq '.Statement | length' "$POLICY_FILE")
echo "📋 Statement count: $STATEMENT_COUNT"

# Effect check
jq -r '.Statement[] | "Statement: \(.Sid // "No Sid") - Effect: \(.Effect)"' "$POLICY_FILE"

echo "✅ Policy validation complete"
```

このドキュメントでは、IAMポリシーの包括的な操作方法を説明しました。実践的な例とベストプラクティスを参考に、セキュアで効率的なポリシー管理を実現してください。
