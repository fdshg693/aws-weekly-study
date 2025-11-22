# EC2 キーペア管理

EC2インスタンスへのSSH接続に使用するキーペアの作成、インポート、管理方法について説明します。

## 目次
- [キーペアの作成](#キーペアの作成)
- [キーペアのインポート](#キーペアのインポート)
- [キーペアの一覧表示](#キーペアの一覧表示)
- [キーペアの詳細情報取得](#キーペアの詳細情報取得)
- [キーペアの削除](#キーペアの削除)
- [キー形式について](#キー形式について)
- [インスタンスでの使用](#インスタンスでの使用)
- [キーローテーションのベストプラクティス](#キーローテーションのベストプラクティス)

---

## キーペアの作成

### 基本的な作成
新しいキーペアを作成し、秘密鍵をファイルに保存します。

```bash
# PEM形式で作成（デフォルト）
aws ec2 create-key-pair \
  --key-name my-key-pair \
  --query 'KeyMaterial' \
  --output text > my-key-pair.pem

# パーミッションを設定
chmod 400 my-key-pair.pem
```

### ED25519形式で作成
よりセキュアなED25519形式でキーペアを作成します。

```bash
aws ec2 create-key-pair \
  --key-name my-ed25519-key \
  --key-type ed25519 \
  --query 'KeyMaterial' \
  --output text > my-ed25519-key.pem

chmod 400 my-ed25519-key.pem
```

### タグ付きで作成
作成時にタグを付与してキーペアを管理します。

```bash
aws ec2 create-key-pair \
  --key-name production-web-key \
  --key-type rsa \
  --tag-specifications 'ResourceType=key-pair,Tags=[{Key=Environment,Value=Production},{Key=Application,Value=WebServer}]' \
  --query 'KeyMaterial' \
  --output text > production-web-key.pem

chmod 400 production-web-key.pem
```

### 作成結果の確認
```bash
# 作成されたキーペアの情報を表示
aws ec2 describe-key-pairs --key-names production-web-key
```

---

## キーペアのインポート

既存の公開鍵をAWSにインポートして使用できます。

### ローカルで鍵ペアを生成
```bash
# RSA鍵の生成
ssh-keygen -t rsa -b 4096 -f ~/.ssh/my-imported-key -C "my-imported-key"

# ED25519鍵の生成（推奨）
ssh-keygen -t ed25519 -f ~/.ssh/my-ed25519-imported-key -C "my-ed25519-key"
```

### 公開鍵をAWSにインポート
```bash
# RSA公開鍵のインポート
aws ec2 import-key-pair \
  --key-name my-imported-key \
  --public-key-material fileb://~/.ssh/my-imported-key.pub

# ED25519公開鍵のインポート
aws ec2 import-key-pair \
  --key-name my-ed25519-imported-key \
  --public-key-material fileb://~/.ssh/my-ed25519-imported-key.pub \
  --tag-specifications 'ResourceType=key-pair,Tags=[{Key=Type,Value=Imported}]'
```

### Base64エンコードされた公開鍵のインポート
```bash
# 公開鍵をBase64エンコード
PUBLIC_KEY=$(cat ~/.ssh/my-imported-key.pub | base64)

# インポート実行
aws ec2 import-key-pair \
  --key-name my-base64-key \
  --public-key-material "$PUBLIC_KEY"
```

---

## キーペアの一覧表示

### すべてのキーペアを表示
```bash
aws ec2 describe-key-pairs
```

### テーブル形式で表示
```bash
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].[KeyName,KeyType,KeyFingerprint]' \
  --output table
```

### 特定のタグでフィルタリング
```bash
# Environment=Productionタグが付いたキーペアを表示
aws ec2 describe-key-pairs \
  --filters "Name=tag:Environment,Values=Production" \
  --query 'KeyPairs[*].[KeyName,KeyType,Tags[?Key==`Environment`].Value|[0]]' \
  --output table
```

### キー形式でフィルタリング
```bash
# ED25519形式のキーペアのみ表示
aws ec2 describe-key-pairs \
  --filters "Name=key-type,Values=ed25519" \
  --query 'KeyPairs[*].[KeyName,KeyType,CreateTime]' \
  --output table
```

---

## キーペアの詳細情報取得

### 特定のキーペア情報を取得
```bash
aws ec2 describe-key-pairs --key-names my-key-pair
```

### 複数のキーペア情報を取得
```bash
aws ec2 describe-key-pairs \
  --key-names my-key-pair production-web-key my-imported-key
```

### フィンガープリントのみ取得
```bash
aws ec2 describe-key-pairs \
  --key-names my-key-pair \
  --query 'KeyPairs[0].KeyFingerprint' \
  --output text
```

### 詳細情報をJSON形式で取得
```bash
aws ec2 describe-key-pairs \
  --key-names my-key-pair \
  --output json | jq '.KeyPairs[0]'
```

---

## キーペアの削除

### 単一のキーペアを削除
```bash
aws ec2 delete-key-pair --key-name my-key-pair
```

### キーIDで削除
```bash
# まずキーIDを取得
KEY_ID=$(aws ec2 describe-key-pairs \
  --key-names my-key-pair \
  --query 'KeyPairs[0].KeyPairId' \
  --output text)

# キーIDで削除
aws ec2 delete-key-pair --key-pair-id "$KEY_ID"
```

### 確認付きで削除
```bash
# 削除前に確認
read -p "キーペア 'old-key' を削除しますか? (y/N): " confirm
if [[ "$confirm" == [yY] ]]; then
  aws ec2 delete-key-pair --key-name old-key
  echo "キーペアを削除しました"
else
  echo "削除をキャンセルしました"
fi
```

### 複数のキーペアを削除
```bash
# 特定のタグが付いたキーペアを削除
aws ec2 describe-key-pairs \
  --filters "Name=tag:Temporary,Values=true" \
  --query 'KeyPairs[*].KeyName' \
  --output text | tr '\t' '\n' | while read key; do
    echo "削除中: $key"
    aws ec2 delete-key-pair --key-name "$key"
done
```

---

## キー形式について

### PEM形式（Privacy Enhanced Mail）
- デフォルトの形式
- RSAおよびED25519キーに対応
- LinuxとmacOSで直接使用可能
- ファイル形式: `-----BEGIN RSA PRIVATE KEY-----` で始まる

```bash
# PEM形式で作成
aws ec2 create-key-pair \
  --key-name pem-key \
  --key-type rsa \
  --query 'KeyMaterial' \
  --output text > pem-key.pem
```

### PPK形式（PuTTY Private Key）
- Windows用PuTTYクライアントで使用
- PEM形式から変換が必要

```bash
# PuTTYgenで変換（Windowsの場合）
# puttygen pem-key.pem -o pem-key.ppk

# Linuxでの変換（putty-toolsが必要）
sudo apt-get install putty-tools  # Debian/Ubuntu
puttygen pem-key.pem -o pem-key.ppk -O private
```

### キー形式の選択基準

| 形式 | ビット数 | セキュリティ | パフォーマンス | 推奨用途 |
|------|----------|--------------|----------------|----------|
| RSA  | 2048-4096 | 高 | 中 | 一般的な用途 |
| ED25519 | 256 | 最高 | 高速 | 新規プロジェクト（推奨） |

---

## インスタンスでの使用

### インスタンス起動時にキーペアを指定
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0
```

### SSH接続の実行
```bash
# パブリックIPを取得
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH接続
ssh -i my-key-pair.pem ec2-user@$PUBLIC_IP

# 詳細ログ付きで接続（デバッグ用）
ssh -v -i my-key-pair.pem ec2-user@$PUBLIC_IP
```

### 複数インスタンスへの接続スクリプト
```bash
#!/bin/bash
KEY_FILE="my-key-pair.pem"
TAG_NAME="Environment"
TAG_VALUE="Production"

# タグでインスタンスを検索してSSH接続
aws ec2 describe-instances \
  --filters "Name=tag:$TAG_NAME,Values=$TAG_VALUE" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text | while read id ip name; do
    echo "接続先: $name ($id - $ip)"
    ssh -i "$KEY_FILE" ec2-user@$ip
done
```

### SSH設定ファイルの作成
```bash
# ~/.ssh/configに設定を追加
cat >> ~/.ssh/config << EOF

Host aws-production-*
  User ec2-user
  IdentityFile ~/.ssh/production-web-key.pem
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host aws-dev-*
  User ec2-user
  IdentityFile ~/.ssh/dev-key.pem
  StrictHostKeyChecking no
EOF

chmod 600 ~/.ssh/config

# 使用例
ssh aws-production-web1  # IPアドレスをHostsファイルで管理
```

---

## キーローテーションのベストプラクティス

### 1. 定期的なキーローテーション計画

#### 新しいキーペアの作成と配布
```bash
#!/bin/bash
# rotate-keys.sh - キーローテーションスクリプト

# 新しいキーペアを作成
NEW_KEY_NAME="production-key-$(date +%Y%m)"
aws ec2 create-key-pair \
  --key-name "$NEW_KEY_NAME" \
  --key-type ed25519 \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=CreatedDate,Value=$(date +%Y-%m-%d)},{Key=Purpose,Value=Rotation}]" \
  --query 'KeyMaterial' \
  --output text > "$NEW_KEY_NAME.pem"

chmod 400 "$NEW_KEY_NAME.pem"

echo "新しいキーペア作成完了: $NEW_KEY_NAME"
```

### 2. 既存インスタンスへの新しい公開鍵の追加
```bash
#!/bin/bash
# add-new-key-to-instances.sh

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

NEW_PUBLIC_KEY=$(cat production-key-202511.pem.pub)

for instance_id in $INSTANCE_IDS; do
  echo "インスタンス $instance_id に新しい鍵を追加中..."
  
  # Systems Managerで公開鍵を追加
  aws ssm send-command \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[
      'echo \"$NEW_PUBLIC_KEY\" >> /home/ec2-user/.ssh/authorized_keys',
      'chmod 600 /home/ec2-user/.ssh/authorized_keys',
      'chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys'
    ]"
done
```

### 3. 古いキーの削除（移行完了後）
```bash
# 90日以上前のキーペアを検索
OLD_DATE=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d "90 days ago" +%Y-%m-%d)

aws ec2 describe-key-pairs \
  --query "KeyPairs[?CreateTime<'$OLD_DATE'].[KeyName,CreateTime]" \
  --output table

# 確認後、古いキーを削除
read -p "これらの古いキーを削除しますか? (y/N): " confirm
if [[ "$confirm" == [yY] ]]; then
  aws ec2 describe-key-pairs \
    --query "KeyPairs[?CreateTime<'$OLD_DATE'].KeyName" \
    --output text | tr '\t' '\n' | while read key; do
      echo "削除中: $key"
      aws ec2 delete-key-pair --key-name "$key"
  done
fi
```

### 4. キー管理のベストプラクティス

#### セキュアな保存
```bash
# キーファイルを暗号化して保存
# GPGを使用した暗号化
gpg --symmetric --cipher-algo AES256 my-key-pair.pem
# 復号化: gpg -d my-key-pair.pem.gpg > my-key-pair.pem

# AWS Secrets Managerに保存
aws secretsmanager create-secret \
  --name production-ssh-key \
  --secret-string file://production-key.pem \
  --description "Production SSH private key" \
  --tags Key=Environment,Value=Production Key=Type,Value=SSHKey
```

#### キー使用の監査
```bash
# CloudTrailでキーペア操作を確認
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::EC2::KeyPair \
  --max-results 50 \
  --query 'Events[*].[EventTime,EventName,Username]' \
  --output table
```

#### アクセス管理
```bash
# キーペアファイルのパーミッションを確認
find ~/.ssh -name "*.pem" -exec ls -la {} \;

# 正しいパーミッションを一括設定
find ~/.ssh -name "*.pem" -exec chmod 400 {} \;
find ~/.ssh -name "*.pub" -exec chmod 644 {} \;
```

### 5. マルチアカウント環境でのキー管理
```bash
#!/bin/bash
# multi-account-key-rotation.sh

ACCOUNTS=("123456789012" "234567890123" "345678901234")
KEY_NAME="shared-admin-key-$(date +%Y%m)"

for account in "${ACCOUNTS[@]}"; do
  echo "アカウント $account でキーペアを作成中..."
  
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --key-type ed25519 \
    --profile "account-$account" \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=ManagedBy,Value=CentralOps},{Key=RotationDate,Value=$(date +%Y-%m-%d)}]" \
    --query 'KeyMaterial' \
    --output text > "${KEY_NAME}-${account}.pem"
  
  chmod 400 "${KEY_NAME}-${account}.pem"
done

echo "すべてのアカウントでキーローテーション完了"
```

### 6. キーペア使用状況の追跡
```bash
# キーペアを使用しているインスタンスを確認
KEY_NAME="my-key-pair"

aws ec2 describe-instances \
  --filters "Name=key-name,Values=$KEY_NAME" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],LaunchTime]' \
  --output table

# 使用されていないキーペアを検出
ALL_KEYS=$(aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text)

for key in $ALL_KEYS; do
  INSTANCE_COUNT=$(aws ec2 describe-instances \
    --filters "Name=key-name,Values=$key" \
    --query 'length(Reservations[*].Instances[*])' \
    --output text)
  
  if [ "$INSTANCE_COUNT" = "0" ]; then
    echo "未使用のキーペア: $key"
  fi
done
```

---

## 補足情報

### トラブルシューティング

#### パーミッションエラー
```bash
# エラー: Permissions 0644 for 'my-key-pair.pem' are too open
chmod 400 my-key-pair.pem

# エラー: Permission denied (publickey)
# 1. キーファイルが正しいか確認
# 2. ユーザー名が正しいか確認（ec2-user, ubuntu, admin等）
# 3. セキュリティグループでSSH(22)が開放されているか確認
```

#### 接続テスト
```bash
# SSH接続をテスト（詳細ログ付き）
ssh -vvv -i my-key-pair.pem ec2-user@$PUBLIC_IP

# Systems Manager Session Managerを使用（キーペア不要）
aws ssm start-session --target i-0123456789abcdef0
```

### 関連コマンド
- `aws ec2 describe-instances` - インスタンスの詳細確認
- `aws ssm send-command` - Systems Managerでコマンド実行
- `aws secretsmanager` - 秘密鍵の安全な保管

### 参考リンク
- [AWS CLI EC2 リファレンス](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
- [Amazon EC2 キーペア](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- [SSH キーペアのベストプラクティス](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair)
