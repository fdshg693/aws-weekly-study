# IAM ユーザー管理

## 目次
- [ユーザーの作成](#ユーザーの作成)
- [ユーザーの一覧表示](#ユーザーの一覧表示)
- [ユーザー情報の取得](#ユーザー情報の取得)
- [ユーザーの更新](#ユーザーの更新)
- [ユーザーの削除](#ユーザーの削除)
- [アクセスキーの管理](#アクセスキーの管理)
- [パスワードの管理](#パスワードの管理)
- [グループへの追加](#グループへの追加)
- [ポリシーのアタッチ](#ポリシーのアタッチ)
- [タグの管理](#タグの管理)
- [実践的な例](#実践的な例)

## ユーザーの作成

### 基本的なユーザー作成
```bash
# シンプルなユーザー作成
aws iam create-user --user-name john-doe

# タグ付きでユーザー作成
aws iam create-user \
  --user-name john-doe \
  --tags Key=Department,Value=Engineering Key=Environment,Value=Production

# パス指定でユーザー作成（組織構造の反映）
aws iam create-user \
  --user-name john-doe \
  --path /engineering/developers/
```

### プログラマティックアクセス用ユーザー
```bash
# ユーザー作成
aws iam create-user --user-name api-user

# アクセスキーの作成
aws iam create-access-key --user-name api-user

# 出力例:
# {
#     "AccessKey": {
#         "UserName": "api-user",
#         "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
#         "Status": "Active",
#         "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
#         "CreateDate": "2024-01-15T10:00:00Z"
#     }
# }
```

### コンソールアクセス用ユーザー
```bash
# ユーザー作成
aws iam create-user --user-name console-user

# ログインプロファイル作成（パスワード設定）
aws iam create-login-profile \
  --user-name console-user \
  --password 'TempPassword123!' \
  --password-reset-required

# パスワード変更不要の場合
aws iam create-login-profile \
  --user-name console-user \
  --password 'SecurePassword123!' \
  --no-password-reset-required
```

## ユーザーの一覧表示

### すべてのユーザーを表示
```bash
# 基本的な一覧表示
aws iam list-users

# ユーザー名のみを表示
aws iam list-users --query 'Users[].UserName' --output table

# 作成日とユーザー名を表示
aws iam list-users \
  --query 'Users[].[UserName,CreateDate]' \
  --output table
```

### パスでフィルタリング
```bash
# 特定パス配下のユーザーのみ表示
aws iam list-users --path-prefix /engineering/

# 複数レベルのパス
aws iam list-users --path-prefix /engineering/developers/
```

### ページネーション
```bash
# 最大数を指定
aws iam list-users --max-items 10

# 次のページを取得
aws iam list-users --max-items 10 --starting-token <token>
```

## ユーザー情報の取得

### 詳細情報の取得
```bash
# 特定ユーザーの情報
aws iam get-user --user-name john-doe

# 現在の認証ユーザー情報
aws iam get-user

# JSONフォーマットで見やすく
aws iam get-user --user-name john-doe | jq
```

### アタッチされたポリシーの確認
```bash
# インラインポリシーの一覧
aws iam list-user-policies --user-name john-doe

# アタッチされた管理ポリシーの一覧
aws iam list-attached-user-policies --user-name john-doe

# すべてのポリシーを表示
aws iam list-attached-user-policies \
  --user-name john-doe \
  --query 'AttachedPolicies[].PolicyName' \
  --output table
```

### グループメンバーシップの確認
```bash
# ユーザーが所属するグループ
aws iam list-groups-for-user --user-name john-doe

# グループ名のみ表示
aws iam list-groups-for-user \
  --user-name john-doe \
  --query 'Groups[].GroupName' \
  --output table
```

### アクセスキーの確認
```bash
# ユーザーのアクセスキー一覧
aws iam list-access-keys --user-name john-doe

# アクセスキーの最終使用日時
aws iam get-access-key-last-used --access-key-id AKIAIOSFODNN7EXAMPLE
```

## ユーザーの更新

### ユーザー名の変更
```bash
# ユーザー名を変更
aws iam update-user \
  --user-name old-username \
  --new-user-name new-username
```

### パスの変更
```bash
# ユーザーのパスを変更
aws iam update-user \
  --user-name john-doe \
  --new-path /engineering/senior-developers/
```

## ユーザーの削除

### 削除前の確認
```bash
# アタッチされているポリシーの確認
aws iam list-attached-user-policies --user-name john-doe
aws iam list-user-policies --user-name john-doe

# 所属グループの確認
aws iam list-groups-for-user --user-name john-doe

# アクセスキーの確認
aws iam list-access-keys --user-name john-doe

# MFAデバイスの確認
aws iam list-mfa-devices --user-name john-doe
```

### 完全な削除スクリプト
```bash
#!/bin/bash
USER_NAME="john-doe"

# アタッチされた管理ポリシーをデタッチ
for policy_arn in $(aws iam list-attached-user-policies \
  --user-name $USER_NAME \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text); do
  echo "Detaching policy: $policy_arn"
  aws iam detach-user-policy --user-name $USER_NAME --policy-arn $policy_arn
done

# インラインポリシーを削除
for policy_name in $(aws iam list-user-policies \
  --user-name $USER_NAME \
  --query 'PolicyNames[]' \
  --output text); do
  echo "Deleting inline policy: $policy_name"
  aws iam delete-user-policy --user-name $USER_NAME --policy-name $policy_name
done

# グループから削除
for group_name in $(aws iam list-groups-for-user \
  --user-name $USER_NAME \
  --query 'Groups[].GroupName' \
  --output text); do
  echo "Removing from group: $group_name"
  aws iam remove-user-from-group --user-name $USER_NAME --group-name $group_name
done

# アクセスキーを削除
for access_key in $(aws iam list-access-keys \
  --user-name $USER_NAME \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text); do
  echo "Deleting access key: $access_key"
  aws iam delete-access-key --user-name $USER_NAME --access-key-id $access_key
done

# ログインプロファイルを削除（存在する場合）
aws iam delete-login-profile --user-name $USER_NAME 2>/dev/null

# MFAデバイスを削除
for serial_number in $(aws iam list-mfa-devices \
  --user-name $USER_NAME \
  --query 'MFADevices[].SerialNumber' \
  --output text); do
  echo "Deactivating MFA device: $serial_number"
  aws iam deactivate-mfa-device --user-name $USER_NAME --serial-number $serial_number
done

# ユーザーを削除
echo "Deleting user: $USER_NAME"
aws iam delete-user --user-name $USER_NAME

echo "User $USER_NAME has been completely deleted."
```

## アクセスキーの管理

### アクセスキーの作成
```bash
# 新しいアクセスキーを作成
aws iam create-access-key --user-name john-doe

# 出力をファイルに保存
aws iam create-access-key --user-name john-doe > access-key-john-doe.json

# CSVフォーマットで保存
aws iam create-access-key --user-name john-doe \
  --query 'AccessKey.[UserName,AccessKeyId,SecretAccessKey]' \
  --output text > access-key.csv
```

### アクセスキーの無効化
```bash
# アクセスキーを無効化
aws iam update-access-key \
  --user-name john-doe \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive

# アクセスキーを再度有効化
aws iam update-access-key \
  --user-name john-doe \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Active
```

### アクセスキーの削除
```bash
# アクセスキーを削除
aws iam delete-access-key \
  --user-name john-doe \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

### アクセスキーのローテーション
```bash
#!/bin/bash
USER_NAME="john-doe"

# 新しいキーを作成
echo "Creating new access key..."
NEW_KEY=$(aws iam create-access-key --user-name $USER_NAME)
NEW_ACCESS_KEY_ID=$(echo $NEW_KEY | jq -r '.AccessKey.AccessKeyId')
NEW_SECRET_KEY=$(echo $NEW_KEY | jq -r '.AccessKey.SecretAccessKey')

echo "New Access Key ID: $NEW_ACCESS_KEY_ID"
echo "New Secret Key: $NEW_SECRET_KEY"
echo "Please update your application configuration with the new credentials."
read -p "Press enter when you've updated and tested the new credentials..."

# 古いキーを一覧表示
echo "Current access keys:"
aws iam list-access-keys --user-name $USER_NAME

read -p "Enter the old access key ID to delete: " OLD_ACCESS_KEY_ID

# 古いキーを削除
aws iam delete-access-key \
  --user-name $USER_NAME \
  --access-key-id $OLD_ACCESS_KEY_ID

echo "Access key rotation completed."
```

## パスワードの管理

### パスワードポリシーの設定
```bash
# アカウント全体のパスワードポリシーを設定
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --allow-users-to-change-password \
  --max-password-age 90 \
  --password-reuse-prevention 5 \
  --hard-expiry

# パスワードポリシーの確認
aws iam get-account-password-policy
```

### ユーザーパスワードの変更
```bash
# 管理者がユーザーのパスワードを変更
aws iam update-login-profile \
  --user-name john-doe \
  --password 'NewSecurePassword123!' \
  --password-reset-required

# パスワード変更不要の場合
aws iam update-login-profile \
  --user-name john-doe \
  --password 'NewSecurePassword123!' \
  --no-password-reset-required
```

### ログインプロファイルの削除
```bash
# コンソールアクセスを無効化
aws iam delete-login-profile --user-name john-doe
```

## グループへの追加

### グループに追加
```bash
# ユーザーをグループに追加
aws iam add-user-to-group \
  --user-name john-doe \
  --group-name developers

# 複数のグループに追加
for group in developers readwrite-access; do
  aws iam add-user-to-group --user-name john-doe --group-name $group
done
```

### グループから削除
```bash
# ユーザーをグループから削除
aws iam remove-user-from-group \
  --user-name john-doe \
  --group-name developers
```

## ポリシーのアタッチ

### 管理ポリシーのアタッチ
```bash
# AWS管理ポリシーをアタッチ
aws iam attach-user-policy \
  --user-name john-doe \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# カスタム管理ポリシーをアタッチ
aws iam attach-user-policy \
  --user-name john-doe \
  --policy-arn arn:aws:iam::123456789012:policy/CustomS3Policy
```

### インラインポリシーの作成
```bash
# インラインポリシーを作成
cat > policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name john-doe \
  --policy-name S3AccessPolicy \
  --policy-document file://policy.json
```

### ポリシーのデタッチ
```bash
# 管理ポリシーをデタッチ
aws iam detach-user-policy \
  --user-name john-doe \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# インラインポリシーを削除
aws iam delete-user-policy \
  --user-name john-doe \
  --policy-name S3AccessPolicy
```

## タグの管理

### タグの追加
```bash
# タグを追加
aws iam tag-user \
  --user-name john-doe \
  --tags Key=Department,Value=Engineering Key=CostCenter,Value=CC123

# 複数のタグを一度に追加
aws iam tag-user \
  --user-name john-doe \
  --tags \
    Key=Environment,Value=Production \
    Key=Team,Value=Backend \
    Key=Project,Value=APIService
```

### タグの一覧表示
```bash
# ユーザーのタグを表示
aws iam list-user-tags --user-name john-doe

# タグの値のみを表示
aws iam list-user-tags \
  --user-name john-doe \
  --query 'Tags[].[Key,Value]' \
  --output table
```

### タグの削除
```bash
# 特定のタグを削除
aws iam untag-user \
  --user-name john-doe \
  --tag-keys Department

# 複数のタグを削除
aws iam untag-user \
  --user-name john-doe \
  --tag-keys Department CostCenter Environment
```

## 実践的な例

### 新入社員のセットアップ
```bash
#!/bin/bash
USER_NAME="$1"
DEPARTMENT="$2"
TEAM="$3"

if [ -z "$USER_NAME" ] || [ -z "$DEPARTMENT" ] || [ -z "$TEAM" ]; then
  echo "Usage: $0 <username> <department> <team>"
  exit 1
fi

# ユーザー作成
echo "Creating user: $USER_NAME"
aws iam create-user \
  --user-name $USER_NAME \
  --tags \
    Key=Department,Value=$DEPARTMENT \
    Key=Team,Value=$TEAM \
    Key=Status,Value=Active

# ログインプロファイル作成
TEMP_PASSWORD=$(openssl rand -base64 12)
aws iam create-login-profile \
  --user-name $USER_NAME \
  --password "$TEMP_PASSWORD" \
  --password-reset-required

# 基本グループに追加
aws iam add-user-to-group --user-name $USER_NAME --group-name all-employees
aws iam add-user-to-group --user-name $USER_NAME --group-name ${DEPARTMENT}-team

# 基本ポリシーをアタッチ
aws iam attach-user-policy \
  --user-name $USER_NAME \
  --policy-arn arn:aws:iam::aws:policy/IAMUserChangePassword

echo "User created successfully!"
echo "Username: $USER_NAME"
echo "Temporary Password: $TEMP_PASSWORD"
echo "Console URL: https://your-account-id.signin.aws.amazon.com/console"
```

### ユーザー監査レポート
```bash
#!/bin/bash
OUTPUT_FILE="iam-user-audit-$(date +%Y%m%d).csv"

echo "Username,CreateDate,PasswordLastUsed,MFAEnabled,AccessKeys,Groups,AttachedPolicies" > $OUTPUT_FILE

for user in $(aws iam list-users --query 'Users[].UserName' --output text); do
  # 基本情報取得
  user_info=$(aws iam get-user --user-name $user)
  create_date=$(echo $user_info | jq -r '.User.CreateDate')
  password_last_used=$(echo $user_info | jq -r '.User.PasswordLastUsed // "Never"')
  
  # MFA確認
  mfa_devices=$(aws iam list-mfa-devices --user-name $user --query 'MFADevices | length(@)')
  mfa_enabled=$([ "$mfa_devices" -gt 0 ] && echo "Yes" || echo "No")
  
  # アクセスキー数
  access_keys=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata | length(@)')
  
  # グループ数
  groups=$(aws iam list-groups-for-user --user-name $user --query 'Groups | length(@)')
  
  # ポリシー数
  policies=$(aws iam list-attached-user-policies --user-name $user --query 'AttachedPolicies | length(@)')
  
  echo "$user,$create_date,$password_last_used,$mfa_enabled,$access_keys,$groups,$policies" >> $OUTPUT_FILE
done

echo "Audit report generated: $OUTPUT_FILE"
```

### 未使用ユーザーの検出
```bash
#!/bin/bash
DAYS_THRESHOLD=90
CUTOFF_DATE=$(date -d "$DAYS_THRESHOLD days ago" +%Y-%m-%d)

echo "Users inactive for more than $DAYS_THRESHOLD days:"
echo "=================================================="

for user in $(aws iam list-users --query 'Users[].UserName' --output text); do
  user_info=$(aws iam get-user --user-name $user)
  password_last_used=$(echo $user_info | jq -r '.User.PasswordLastUsed // "1970-01-01"')
  
  # アクセスキーの最終使用日を確認
  latest_key_used="1970-01-01"
  for key_id in $(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
    key_last_used=$(aws iam get-access-key-last-used --access-key-id $key_id --query 'AccessKeyLastUsed.LastUsedDate' --output text 2>/dev/null || echo "1970-01-01")
    if [[ "$key_last_used" > "$latest_key_used" ]]; then
      latest_key_used=$key_last_used
    fi
  done
  
  # 最後のアクティビティ日を決定
  if [[ "$password_last_used" > "$latest_key_used" ]]; then
    last_activity=$password_last_used
  else
    last_activity=$latest_key_used
  fi
  
  # カットオフ日より前かチェック
  if [[ "$last_activity" < "$CUTOFF_DATE" ]]; then
    echo "User: $user"
    echo "  Last Activity: $last_activity"
    echo "  Days Inactive: $(( ($(date +%s) - $(date -d "$last_activity" +%s)) / 86400 ))"
    echo ""
  fi
done
```

### アクセスキーのセキュリティチェック
```bash
#!/bin/bash
MAX_KEY_AGE_DAYS=90
CUTOFF_DATE=$(date -d "$MAX_KEY_AGE_DAYS days ago" +%Y-%m-%d)

echo "Access Key Security Report"
echo "=========================="
echo ""

for user in $(aws iam list-users --query 'Users[].UserName' --output text); do
  access_keys=$(aws iam list-access-keys --user-name $user)
  key_count=$(echo $access_keys | jq -r '.AccessKeyMetadata | length')
  
  if [ "$key_count" -gt 0 ]; then
    echo "User: $user"
    
    # 複数キーの警告
    if [ "$key_count" -gt 1 ]; then
      echo "  ⚠️  WARNING: Multiple access keys ($key_count)"
    fi
    
    # 各キーをチェック
    echo $access_keys | jq -r '.AccessKeyMetadata[] | [.AccessKeyId, .CreateDate, .Status] | @tsv' | \
    while IFS=$'\t' read -r key_id create_date status; do
      echo "  Key: $key_id"
      echo "    Status: $status"
      echo "    Created: $create_date"
      
      # キーの年齢チェック
      if [[ "$create_date" < "$CUTOFF_DATE" ]]; then
        days_old=$(( ($(date +%s) - $(date -d "${create_date:0:10}" +%s)) / 86400 ))
        echo "    ⚠️  WARNING: Key is $days_old days old (threshold: $MAX_KEY_AGE_DAYS days)"
      fi
      
      # 最終使用日チェック
      last_used=$(aws iam get-access-key-last-used --access-key-id $key_id 2>/dev/null)
      if [ $? -eq 0 ]; then
        last_used_date=$(echo $last_used | jq -r '.AccessKeyLastUsed.LastUsedDate // "Never"')
        last_used_service=$(echo $last_used | jq -r '.AccessKeyLastUsed.ServiceName // "N/A"')
        echo "    Last Used: $last_used_date ($last_used_service)"
      fi
      
      echo ""
    done
  fi
done
```

## ベストプラクティス

### セキュリティ
1. **最小権限の原則**: 必要最小限の権限のみを付与
2. **MFAの有効化**: すべてのユーザーにMFAを要求
3. **定期的なアクセスキーローテーション**: 90日ごとにローテーション
4. **未使用ユーザーの削除**: 定期的に監査して不要なユーザーを削除
5. **強力なパスワードポリシー**: 複雑さと定期変更を要求

### 管理
1. **命名規則の統一**: 組織的な命名規則を採用
2. **タグの活用**: コスト配分と管理のためにタグを使用
3. **グループの活用**: 個別ユーザーではなくグループにポリシーをアタッチ
4. **定期的な監査**: アクセスログと権限の定期的なレビュー
5. **ドキュメント化**: ユーザーの役割と権限を文書化

### 自動化
1. **オンボーディングスクリプト**: 新入社員セットアップの自動化
2. **監査レポート**: 定期的なセキュリティレポートの生成
3. **アラート**: 異常なアクティビティの検出と通知
4. **ローテーション**: アクセスキーの自動ローテーション
5. **クリーンアップ**: 未使用リソースの自動削除
