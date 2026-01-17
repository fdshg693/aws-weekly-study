# セキュリティグループ (Security Groups)

## 目次
- [概要](#概要)
- [セキュリティグループの作成](#セキュリティグループの作成)
- [セキュリティグループの確認](#セキュリティグループの確認)
- [インバウンドルールの追加](#インバウンドルールの追加)
- [アウトバウンドルールの追加](#アウトバウンドルールの追加)
- [ルールの削除](#ルールの削除)
- [セキュリティグループの変更](#セキュリティグループの変更)
- [セキュリティグループの削除](#セキュリティグループの削除)
- [タグ管理](#タグ管理)
- [一般的なポート設定](#一般的なポート設定)
- [ベストプラクティス](#ベストプラクティス)

---

## 概要

セキュリティグループは、EC2インスタンスへの仮想ファイアウォールとして機能し、インバウンドとアウトバウンドのトラフィックを制御します。

### 重要な特徴
- **ステートフル**: インバウンドで許可されたトラフィックの応答は自動的に許可される
- **デフォルトの動作**: すべてのインバウンドトラフィックは拒否、すべてのアウトバウンドトラフィックは許可
- **複数アタッチ**: 1つのインスタンスに複数のセキュリティグループを適用可能

---

## セキュリティグループの作成

### 基本的な作成

```bash
# 基本的なセキュリティグループの作成
aws ec2 create-security-group \
    --group-name my-security-group \
    --description "My security group description" \
    --vpc-id vpc-1234567890abcdef0
```

**レスポンス例:**
```json
{
    "GroupId": "sg-0123456789abcdef0"
}
```

### タグ付きで作成

```bash
# タグを含めて作成
aws ec2 create-security-group \
    --group-name web-server-sg \
    --description "Security group for web servers" \
    --vpc-id vpc-1234567890abcdef0 \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=WebServerSG},{Key=Environment,Value=Production},{Key=Application,Value=WebApp}]'
```

### 変数を使用した作成

```bash
# 変数を使用した柔軟な作成
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=MyVPC" --query 'Vpcs[0].VpcId' --output text)

SG_ID=$(aws ec2 create-security-group \
    --group-name app-server-sg \
    --description "Application server security group" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

echo "Created Security Group: $SG_ID"
```

---

## セキュリティグループの確認

### すべてのセキュリティグループを表示

```bash
# すべてのセキュリティグループを表示
aws ec2 describe-security-groups
```

### 特定のセキュリティグループを表示

```bash
# セキュリティグループIDで検索
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0

# セキュリティグループ名で検索
aws ec2 describe-security-groups \
    --group-names my-security-group
```

### フィルターを使用した検索

```bash
# VPCで絞り込み
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=vpc-1234567890abcdef0"

# タグで絞り込み
aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=Production"

# グループ名のパターンで絞り込み
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*web*"
```

### カスタム出力フォーマット

```bash
# 簡潔な一覧表示
aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description,VpcId]' \
    --output table

# 特定の情報のみ抽出
aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName,VPC:VpcId}' \
    --output table

# ルール情報を含む詳細表示
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,InboundRules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,CIDR:IpRanges[0].CidrIp}}' \
    --output json
```

### インバウンド/アウトバウンドルールの確認

```bash
# インバウンドルールのみ表示
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissions' \
    --output json

# アウトバウンドルールのみ表示
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissionsEgress' \
    --output json
```

---

## インバウンドルールの追加

### 基本的なルール追加

```bash
# 単一のIPアドレスからのSSHアクセスを許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --cidr 203.0.113.0/32
```

### 複数のルールを一度に追加

```bash
# JSONファイルを使用した複数ルールの追加
cat > ingress-rules.json << 'EOF'
[
  {
    "IpProtocol": "tcp",
    "FromPort": 80,
    "ToPort": 80,
    "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTP from anywhere"}]
  },
  {
    "IpProtocol": "tcp",
    "FromPort": 443,
    "ToPort": 443,
    "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTPS from anywhere"}]
  },
  {
    "IpProtocol": "tcp",
    "FromPort": 22,
    "ToPort": 22,
    "IpRanges": [{"CidrIp": "10.0.0.0/16", "Description": "SSH from VPC"}]
  }
]
EOF

aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions file://ingress-rules.json
```

### CIDR範囲でのルール追加

```bash
# 特定のCIDR範囲からのアクセスを許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 3306 \
    --cidr 10.0.1.0/24 \
    --description "MySQL from private subnet"

# 複数のCIDR範囲を指定
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=tcp,FromPort=5432,ToPort=5432,IpRanges='[{CidrIp=10.0.1.0/24,Description="PostgreSQL from subnet A"},{CidrIp=10.0.2.0/24,Description="PostgreSQL from subnet B"}]'
```

### セキュリティグループ間のルール追加

```bash
# 別のセキュリティグループからのアクセスを許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-9876543210fedcba0 \
    --description "MySQL from application servers"

# 異なるAWSアカウントのセキュリティグループからのアクセス
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs='[{GroupId=sg-9876543210fedcba0,UserId=123456789012,Description="HTTP from partner account"}]'
```

### ポート範囲の指定

```bash
# ポート範囲を指定
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 8000-8999 \
    --cidr 10.0.0.0/8 \
    --description "Custom application ports"
```

### ICMPルールの追加

```bash
# すべてのICMPを許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol icmp \
    --port -1 \
    --cidr 10.0.0.0/16 \
    --description "ICMP from VPC"

# Pingのみ許可 (ICMP Echo Request)
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=-1,IpRanges='[{CidrIp=0.0.0.0/0,Description="Ping from anywhere"}]'
```

---

## アウトバウンドルールの追加

### 基本的なアウトバウンドルール

```bash
# HTTPSアウトバウンドを許可
aws ec2 authorize-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS to internet"
```

### 複数のアウトバウンドルール

```bash
# 複数のアウトバウンドルールを一度に追加
cat > egress-rules.json << 'EOF'
[
  {
    "IpProtocol": "tcp",
    "FromPort": 443,
    "ToPort": 443,
    "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTPS to internet"}]
  },
  {
    "IpProtocol": "tcp",
    "FromPort": 3306,
    "ToPort": 3306,
    "UserIdGroupPairs": [{"GroupId": "sg-database123", "Description": "MySQL to database"}]
  },
  {
    "IpProtocol": "tcp",
    "FromPort": 6379,
    "ToPort": 6379,
    "UserIdGroupPairs": [{"GroupId": "sg-redis123", "Description": "Redis to cache"}]
  }
]
EOF

aws ec2 authorize-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions file://egress-rules.json
```

### デフォルトのアウトバウンドルール削除と再設定

```bash
# デフォルトの「すべて許可」ルールを削除
aws ec2 revoke-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]'

# 特定のアウトバウンドのみ許可
aws ec2 authorize-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS only"
```

---

## ルールの削除

### インバウンドルールの削除

```bash
# 特定のインバウンドルールを削除
aws ec2 revoke-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --cidr 203.0.113.0/32

# 複数のルールを一度に削除
aws ec2 revoke-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]' IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'
```

### アウトバウンドルールの削除

```bash
# 特定のアウトバウンドルールを削除
aws ec2 revoke-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 3306 \
    --cidr 10.0.1.0/24
```

### JSONファイルを使用したルール削除

```bash
# 現在のルールを取得して削除用JSONを作成
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissions' \
    > current-rules.json

# 削除したいルールをJSONファイルから選択して削除
aws ec2 revoke-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions file://rules-to-remove.json
```

### セキュリティグループ参照ルールの削除

```bash
# セキュリティグループIDを参照しているルールを削除
aws ec2 revoke-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=tcp,FromPort=3306,ToPort=3306,UserIdGroupPairs='[{GroupId=sg-9876543210fedcba0}]'
```

---

## セキュリティグループの変更

### 名前と説明の更新

```bash
# セキュリティグループの説明は作成後に変更できない
# 新しいセキュリティグループを作成してルールをコピーする必要がある

# ルールをエクスポート
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissions' \
    > old-sg-rules.json

# 新しいセキュリティグループを作成
NEW_SG_ID=$(aws ec2 create-security-group \
    --group-name new-security-group \
    --description "Updated description" \
    --vpc-id vpc-1234567890abcdef0 \
    --query 'GroupId' \
    --output text)

# ルールをインポート
aws ec2 authorize-security-group-ingress \
    --group-id $NEW_SG_ID \
    --ip-permissions file://old-sg-rules.json
```

### タグの更新

```bash
# タグを追加/更新
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=Name,Value=UpdatedSGName Key=Environment,Value=Staging

# タグを削除
aws ec2 delete-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=OldTag
```

### インスタンスへのセキュリティグループの適用

```bash
# インスタンスのセキュリティグループを変更
aws ec2 modify-instance-attribute \
    --instance-id i-1234567890abcdef0 \
    --groups sg-0123456789abcdef0 sg-9876543210fedcba0

# 現在のセキュリティグループを確認
aws ec2 describe-instances \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].SecurityGroups'
```

---

## セキュリティグループの削除

### 基本的な削除

```bash
# セキュリティグループを削除
aws ec2 delete-security-group \
    --group-id sg-0123456789abcdef0

# または名前で削除
aws ec2 delete-security-group \
    --group-name my-security-group
```

### 削除前の確認とクリーンアップ

```bash
# セキュリティグループを使用しているインスタンスを確認
aws ec2 describe-instances \
    --filters "Name=instance.group-id,Values=sg-0123456789abcdef0" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
    --output table

# ネットワークインターフェースでの使用を確認
aws ec2 describe-network-interfaces \
    --filters "Name=group-id,Values=sg-0123456789abcdef0" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Attachment.InstanceId]' \
    --output table

# 他のセキュリティグループからの参照を確認
aws ec2 describe-security-groups \
    --filters "Name=ip-permission.group-id,Values=sg-0123456789abcdef0" \
    --query 'SecurityGroups[*].[GroupId,GroupName]' \
    --output table
```

### 一括削除スクリプト

```bash
# 特定のタグを持つセキュリティグループを一括削除
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=Test" \
    --query 'SecurityGroups[*].GroupId' \
    --output text)

for SG_ID in $SG_IDS; do
    echo "Deleting security group: $SG_ID"
    aws ec2 delete-security-group --group-id $SG_ID 2>&1 | grep -v "DependencyViolation" || true
done
```

---

## タグ管理

### タグの追加

```bash
# 単一タグの追加
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=Name,Value=WebServerSG

# 複数タグの追加
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=Environment,Value=Production Key=Application,Value=WebApp Key=CostCenter,Value=Engineering
```

### タグの確認

```bash
# セキュリティグループのタグを表示
aws ec2 describe-tags \
    --filters "Name=resource-id,Values=sg-0123456789abcdef0" \
    --output table

# タグを含むセキュリティグループ情報
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Tags:Tags}' \
    --output json
```

### タグでの検索とフィルタリング

```bash
# 特定のタグを持つセキュリティグループを検索
aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=Production" \
    --query 'SecurityGroups[*].[GroupId,GroupName,Tags[?Key==`Name`].Value|[0]]' \
    --output table

# 複数のタグで絞り込み
aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=Production" "Name=tag:Application,Values=WebApp" \
    --output table
```

### タグの更新と削除

```bash
# タグの値を更新（上書き）
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=Environment,Value=Staging

# 特定のタグを削除
aws ec2 delete-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=OldTag

# 複数のタグを削除
aws ec2 delete-tags \
    --resources sg-0123456789abcdef0 \
    --tags Key=Tag1 Key=Tag2 Key=Tag3
```

### 複数リソースへの一括タグ付け

```bash
# 複数のセキュリティグループに同じタグを適用
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 sg-9876543210fedcba0 sg-1111111111111111 \
    --tags Key=Environment,Value=Production Key=ManagedBy,Value=DevOpsTeam
```

---

## 一般的なポート設定

### Webサーバー (HTTP/HTTPS)

```bash
# Webサーバー用セキュリティグループ
aws ec2 create-security-group \
    --group-name web-server-sg \
    --description "Security group for web servers" \
    --vpc-id vpc-1234567890abcdef0

SG_ID=$(aws ec2 describe-security-groups \
    --group-names web-server-sg \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# HTTP (80)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --description "HTTP from internet"

# HTTPS (443)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS from internet"
```

### SSHアクセス

```bash
# 管理者用SSH (22)
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --cidr 203.0.113.0/24 \
    --description "SSH from office network"

# 踏み台サーバー経由のSSH
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --source-group sg-bastion123 \
    --description "SSH from bastion host"
```

### データベース

```bash
# MySQL/MariaDB (3306)
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-appserver123 \
    --description "MySQL from application servers"

# PostgreSQL (5432)
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 5432 \
    --source-group sg-appserver123 \
    --description "PostgreSQL from application servers"

# MongoDB (27017)
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 27017 \
    --source-group sg-appserver123 \
    --description "MongoDB from application servers"

# Redis (6379)
aws ec2 authorize-security-group-ingress \
    --group-id sg-cache123 \
    --protocol tcp \
    --port 6379 \
    --source-group sg-appserver123 \
    --description "Redis from application servers"

# Microsoft SQL Server (1433)
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 1433 \
    --source-group sg-appserver123 \
    --description "SQL Server from application servers"

# Oracle DB (1521)
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 1521 \
    --source-group sg-appserver123 \
    --description "Oracle DB from application servers"
```

### アプリケーションサーバー

```bash
# カスタムアプリケーションポート (8080)
aws ec2 authorize-security-group-ingress \
    --group-id sg-appserver123 \
    --protocol tcp \
    --port 8080 \
    --source-group sg-loadbalancer123 \
    --description "Application from load balancer"

# Node.js (3000)
aws ec2 authorize-security-group-ingress \
    --group-id sg-appserver123 \
    --protocol tcp \
    --port 3000 \
    --source-group sg-loadbalancer123 \
    --description "Node.js from load balancer"

# Tomcat (8080, 8443)
aws ec2 authorize-security-group-ingress \
    --group-id sg-appserver123 \
    --protocol tcp \
    --port 8080 \
    --source-group sg-loadbalancer123 \
    --description "Tomcat HTTP from load balancer"
```

### メールサーバー

```bash
# SMTP (25, 587)
aws ec2 authorize-security-group-ingress \
    --group-id sg-mailserver123 \
    --protocol tcp \
    --port 587 \
    --cidr 10.0.0.0/16 \
    --description "SMTP submission from VPC"

# SMTPS (465)
aws ec2 authorize-security-group-ingress \
    --group-id sg-mailserver123 \
    --protocol tcp \
    --port 465 \
    --cidr 10.0.0.0/16 \
    --description "SMTPS from VPC"

# IMAP (143, 993)
aws ec2 authorize-security-group-ingress \
    --group-id sg-mailserver123 \
    --protocol tcp \
    --port 993 \
    --cidr 10.0.0.0/16 \
    --description "IMAPS from VPC"

# POP3 (110, 995)
aws ec2 authorize-security-group-ingress \
    --group-id sg-mailserver123 \
    --protocol tcp \
    --port 995 \
    --cidr 10.0.0.0/16 \
    --description "POP3S from VPC"
```

### ロードバランサー

```bash
# ALB/ELB (80, 443)
aws ec2 authorize-security-group-ingress \
    --group-id sg-loadbalancer123 \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --description "HTTP from internet"

aws ec2 authorize-security-group-ingress \
    --group-id sg-loadbalancer123 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS from internet"
```

### その他のサービス

```bash
# DNS (53)
aws ec2 authorize-security-group-ingress \
    --group-id sg-dns123 \
    --protocol udp \
    --port 53 \
    --cidr 10.0.0.0/16 \
    --description "DNS from VPC"

# NTP (123)
aws ec2 authorize-security-group-ingress \
    --group-id sg-ntp123 \
    --protocol udp \
    --port 123 \
    --cidr 10.0.0.0/16 \
    --description "NTP from VPC"

# LDAP (389, 636)
aws ec2 authorize-security-group-ingress \
    --group-id sg-ldap123 \
    --protocol tcp \
    --port 636 \
    --cidr 10.0.0.0/16 \
    --description "LDAPS from VPC"

# Docker (2376, 2377)
aws ec2 authorize-security-group-ingress \
    --group-id sg-docker123 \
    --protocol tcp \
    --port 2377 \
    --source-group sg-docker123 \
    --description "Docker Swarm from cluster nodes"

# Kubernetes (6443, 10250-10252)
aws ec2 authorize-security-group-ingress \
    --group-id sg-k8s123 \
    --protocol tcp \
    --port 6443 \
    --cidr 10.0.0.0/16 \
    --description "Kubernetes API from VPC"

# Elasticsearch (9200, 9300)
aws ec2 authorize-security-group-ingress \
    --group-id sg-elasticsearch123 \
    --protocol tcp \
    --port 9200 \
    --source-group sg-appserver123 \
    --description "Elasticsearch HTTP from application servers"
```

---

## ベストプラクティス

### 1. 最小権限の原則

```bash
# ❌ 悪い例: すべてのポートを全世界に開放
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 0-65535 \
    --cidr 0.0.0.0/0

# ✅ 良い例: 必要なポートのみを特定のソースに開放
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS only from internet"

aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --cidr 203.0.113.0/24 \
    --description "SSH from office only"
```

### 2. セキュリティグループIDの参照を使用

```bash
# ✅ CIDR範囲よりもセキュリティグループIDを参照する
# これにより、IPアドレスが変更されても自動的に対応できる
aws ec2 authorize-security-group-ingress \
    --group-id sg-database123 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-appserver123 \
    --description "MySQL from application tier"
```

### 3. 説明フィールドの活用

```bash
# ✅ 常に説明を追加して、ルールの目的を明確にする
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --description "HTTPS for public web service - Ticket #12345"
```

### 4. タグを使用した管理

```bash
# ✅ タグを使用してセキュリティグループを分類
aws ec2 create-tags \
    --resources sg-0123456789abcdef0 \
    --tags \
        Key=Name,Value=WebServerSG \
        Key=Environment,Value=Production \
        Key=Application,Value=ECommerce \
        Key=Owner,Value=DevOpsTeam \
        Key=CostCenter,Value=Engineering \
        Key=Compliance,Value=PCI-DSS
```

### 5. 階層的なセキュリティグループ設計

```bash
# Web層
WEB_SG=$(aws ec2 create-security-group \
    --group-name web-tier-sg \
    --description "Web tier security group" \
    --vpc-id vpc-1234567890abcdef0 \
    --query 'GroupId' --output text)

# アプリケーション層
APP_SG=$(aws ec2 create-security-group \
    --group-name app-tier-sg \
    --description "Application tier security group" \
    --vpc-id vpc-1234567890abcdef0 \
    --query 'GroupId' --output text)

# データベース層
DB_SG=$(aws ec2 create-security-group \
    --group-name db-tier-sg \
    --description "Database tier security group" \
    --vpc-id vpc-1234567890abcdef0 \
    --query 'GroupId' --output text)

# Web層の設定
aws ec2 authorize-security-group-ingress \
    --group-id $WEB_SG \
    --protocol tcp --port 443 --cidr 0.0.0.0/0 \
    --description "HTTPS from internet"

# アプリケーション層の設定（Web層からのみ）
aws ec2 authorize-security-group-ingress \
    --group-id $APP_SG \
    --protocol tcp --port 8080 --source-group $WEB_SG \
    --description "Application from web tier"

# データベース層の設定（アプリケーション層からのみ）
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG \
    --protocol tcp --port 3306 --source-group $APP_SG \
    --description "MySQL from application tier"
```

### 6. 定期的な監査とクリーンアップ

```bash
# 未使用のセキュリティグループを検索
# まず、使用中のセキュリティグループを取得
USED_SGS=$(aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
    --output text | tr '\t' '\n' | sort -u)

# すべてのセキュリティグループを取得
ALL_SGS=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].GroupId' \
    --output text | tr '\t' '\n' | sort -u)

# 差分を表示（未使用のセキュリティグループ）
echo "Unused Security Groups:"
comm -23 <(echo "$ALL_SGS") <(echo "$USED_SGS")

# 過度に緩いルールを検出
echo "Security groups with 0.0.0.0/0 on non-standard ports:"
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`] && (FromPort!=`80` && FromPort!=`443`)]].[GroupId,GroupName]' \
    --output table
```

### 7. SSHアクセスの制限

```bash
# ❌ 悪い例: SSHを全世界に開放
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

# ✅ 良い例: 特定のIPまたは踏み台サーバー経由のみ
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 22 --source-group sg-bastion \
    --description "SSH from bastion host only"
```

### 8. アウトバウンドトラフィックの制限

```bash
# デフォルトのすべて許可ルールを削除
aws ec2 revoke-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]'

# 必要なアウトバウンドのみ許可
# HTTPS (パッケージ更新用)
aws ec2 authorize-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 443 --cidr 0.0.0.0/0 \
    --description "HTTPS for updates"

# データベースへのアクセス
aws ec2 authorize-security-group-egress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 3306 --source-group sg-database123 \
    --description "MySQL to database tier"
```

### 9. セキュリティグループの命名規則

```bash
# 一貫した命名規則を使用
# フォーマット: <environment>-<tier>-<purpose>-sg

aws ec2 create-security-group \
    --group-name prod-web-frontend-sg \
    --description "Production Web Frontend Security Group" \
    --vpc-id vpc-1234567890abcdef0

aws ec2 create-security-group \
    --group-name prod-app-backend-sg \
    --description "Production Application Backend Security Group" \
    --vpc-id vpc-1234567890abcdef0

aws ec2 create-security-group \
    --group-name prod-db-mysql-sg \
    --description "Production Database MySQL Security Group" \
    --vpc-id vpc-1234567890abcdef0
```

### 10. バックアップとバージョン管理

```bash
# セキュリティグループの設定をバックアップ
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    > sg-backup-$(date +%Y%m%d-%H%M%S).json

# すべてのセキュリティグループをバックアップ
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=vpc-1234567890abcdef0" \
    > all-sgs-backup-$(date +%Y%m%d-%H%M%S).json

# Gitで管理するスクリプト例
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR="./security-group-backups"
mkdir -p $BACKUP_DIR

aws ec2 describe-security-groups \
    --query 'SecurityGroups[*]' \
    > $BACKUP_DIR/security-groups-$DATE.json

cd $BACKUP_DIR
git add .
git commit -m "Security group backup - $DATE"
git push
```

### 11. 変更のテストと検証

```bash
# ルール追加前にテスト
# 1. 現在の設定を保存
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    > sg-before-change.json

# 2. 変更を適用
aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 8080 --cidr 10.0.0.0/16

# 3. 接続テスト
# (アプリケーションレベルでテスト)

# 4. 問題があれば元に戻す
aws ec2 revoke-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 8080 --cidr 10.0.0.0/16
```

### 12. CloudFormationまたはTerraformでの管理

```bash
# Infrastructure as Codeを使用して管理
# これにより、変更履歴の追跡、レビュー、ロールバックが容易になる

# セキュリティグループの設定をエクスポート
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --output json \
    > export-for-iac.json

# この情報を使ってTerraformやCloudFormationテンプレートを作成
```

---

## 実践的なシナリオ例

### シナリオ1: 3層Webアプリケーション

```bash
#!/bin/bash
VPC_ID="vpc-1234567890abcdef0"

# Web層のセキュリティグループ
WEB_SG=$(aws ec2 create-security-group \
    --group-name prod-web-tier-sg \
    --description "Production Web Tier" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ProdWebTier},{Key=Layer,Value=Web}]' \
    --query 'GroupId' --output text)

# アプリケーション層
APP_SG=$(aws ec2 create-security-group \
    --group-name prod-app-tier-sg \
    --description "Production Application Tier" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ProdAppTier},{Key=Layer,Value=Application}]' \
    --query 'GroupId' --output text)

# データベース層
DB_SG=$(aws ec2 create-security-group \
    --group-name prod-db-tier-sg \
    --description "Production Database Tier" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ProdDBTier},{Key=Layer,Value=Database}]' \
    --query 'GroupId' --output text)

# Web層のルール設定
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --description "HTTP from internet"
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0 --description "HTTPS from internet"

# アプリケーション層のルール設定
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 8080 --source-group $WEB_SG --description "App from web tier"

# データベース層のルール設定
aws ec2 authorize-security-group-ingress --group-id $DB_SG --protocol tcp --port 3306 --source-group $APP_SG --description "MySQL from app tier"

echo "Web SG: $WEB_SG"
echo "App SG: $APP_SG"
echo "DB SG: $DB_SG"
```

### シナリオ2: 開発環境から本番環境への移行

```bash
#!/bin/bash
# 開発環境のセキュリティグループを本番環境にコピー

DEV_SG_ID="sg-dev123"
PROD_VPC_ID="vpc-prod456"

# 開発環境の設定を取得
DEV_SG_CONFIG=$(aws ec2 describe-security-groups --group-ids $DEV_SG_ID)
DEV_SG_NAME=$(echo $DEV_SG_CONFIG | jq -r '.SecurityGroups[0].GroupName')
DEV_SG_DESC=$(echo $DEV_SG_CONFIG | jq -r '.SecurityGroups[0].Description')

# 本番環境用の名前に変更
PROD_SG_NAME="prod-${DEV_SG_NAME#dev-}"

# 本番環境にセキュリティグループを作成
PROD_SG_ID=$(aws ec2 create-security-group \
    --group-name $PROD_SG_NAME \
    --description "$DEV_SG_DESC (Production)" \
    --vpc-id $PROD_VPC_ID \
    --query 'GroupId' --output text)

# インバウンドルールを取得してコピー
echo $DEV_SG_CONFIG | jq -r '.SecurityGroups[0].IpPermissions' > /tmp/ingress-rules.json

# CIDRルールのみコピー（セキュリティグループIDは環境依存のため除外）
aws ec2 authorize-security-group-ingress \
    --group-id $PROD_SG_ID \
    --ip-permissions "$(cat /tmp/ingress-rules.json | jq '[.[] | select(.UserIdGroupPairs == null or (.UserIdGroupPairs | length == 0))]')"

echo "Created production security group: $PROD_SG_ID"
echo "Manual review required for cross-security-group references"
```

### シナリオ3: セキュリティ監査レポート

```bash
#!/bin/bash
# セキュリティグループの監査レポートを生成

echo "=== Security Group Audit Report ==="
echo "Generated: $(date)"
echo ""

# 1. 0.0.0.0/0でSSHが開いているセキュリティグループ
echo "### Security Groups with SSH open to 0.0.0.0/0:"
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && ToPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId,GroupName]' \
    --output table

echo ""

# 2. すべてのポートが開いているセキュリティグループ
echo "### Security Groups with all ports open:"
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?IpProtocol==`-1` && IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId,GroupName]' \
    --output table

echo ""

# 3. 未使用のセキュリティグループ
echo "### Unused Security Groups:"
USED_SGS=$(aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].Groups[*].GroupId' --output text | tr '\t' '\n' | sort -u)
ALL_SGS=$(aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | tr '\t' '\n' | sort -u)
comm -23 <(echo "$ALL_SGS") <(echo "$USED_SGS")

echo ""

# 4. タグが付いていないセキュリティグループ
echo "### Security Groups without tags:"
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?Tags==null || Tags==``].[GroupId,GroupName]' \
    --output table
```

---

## トラブルシューティング

### ルール追加時のエラー

```bash
# エラー: InvalidPermission.Duplicate
# 原因: 同じルールが既に存在
# 解決策: 既存のルールを確認
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissions'

# エラー: InvalidGroup.InUse
# 原因: セキュリティグループが使用中
# 解決策: 使用中のリソースを確認
aws ec2 describe-network-interfaces \
    --filters "Name=group-id,Values=sg-0123456789abcdef0"

# エラー: RulesPerSecurityGroupLimitExceeded
# 原因: セキュリティグループあたりのルール数上限に達した
# 解決策: ルールを統合するか、複数のセキュリティグループに分割
```

### 接続テスト

```bash
# セキュリティグループの設定が正しいか確認
# 1. ルールの確認
aws ec2 describe-security-groups \
    --group-ids sg-0123456789abcdef0 \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'

# 2. インスタンスのセキュリティグループ確認
aws ec2 describe-instances \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].SecurityGroups'

# 3. ネットワークACLも確認（セキュリティグループとは別のレイヤー）
SUBNET_ID=$(aws ec2 describe-instances \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].SubnetId' \
    --output text)

aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_ID"
```

---

## まとめ

セキュリティグループは、AWSのネットワークセキュリティの基本であり、適切に設定することで、インフラストラクチャを外部および内部の脅威から保護できます。

### 重要なポイント
1. **最小権限の原則**: 必要最小限のアクセスのみ許可
2. **セキュリティグループIDの活用**: IP範囲よりも柔軟で管理しやすい
3. **階層的な設計**: 3層アーキテクチャなどで適切に分離
4. **定期的な監査**: 未使用のルールやセキュリティグループを削除
5. **IaCでの管理**: 変更履歴とレビューのためにコード化
6. **適切なタグ付け**: 管理とコスト配分のために重要
7. **ドキュメント化**: ルールの目的を説明フィールドに記載

### 参考リンク
- [AWS CLI Command Reference - EC2](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
- [セキュリティグループのルール](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html)
- [VPCのセキュリティグループ](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
