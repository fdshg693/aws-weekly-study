# EC2 describe-instances フィルタリング

## 概要

`describe-instances` コマンドは、EC2インスタンスの情報を取得するための基本コマンドです。フィルタリング機能を使用することで、必要な情報を効率的に取得できます。

## 基本構文

```bash
aws ec2 describe-instances [options]
```

## describe-instances コマンドの基本

### すべてのインスタンスを取得

```bash
aws ec2 describe-instances
```

### 特定のインスタンスIDで取得

```bash
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
```

### 複数のインスタンスIDで取得

```bash
aws ec2 describe-instances --instance-ids i-1234567890abcdef0 i-0987654321fedcba0
```

## フィルタリングの基本

### --filters オプションの構文

```bash
aws ec2 describe-instances --filters "Name=filter-name,Values=value1,value2"
```

複数のフィルタを組み合わせる場合:

```bash
aws ec2 describe-instances \
  --filters \
    "Name=filter-name1,Values=value1" \
    "Name=filter-name2,Values=value2"
```

## インスタンスステータスによるフィルタリング

### 実行中のインスタンスのみ取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running"
```

### 停止中のインスタンスのみ取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=stopped"
```

### 複数のステータスで取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped"
```

### 利用可能なインスタンスステータス

- `pending` - 起動準備中
- `running` - 実行中
- `stopping` - 停止処理中
- `stopped` - 停止済み
- `shutting-down` - 終了処理中
- `terminated` - 終了済み

## インスタンスタイプによるフィルタリング

### 特定のインスタンスタイプで取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-type,Values=t2.micro"
```

### 複数のインスタンスタイプで取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-type,Values=t2.micro,t2.small,t3.micro"
```

### t3ファミリーのすべてのインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters "Name=instance-type,Values=t3.*"
```

## タグによるフィルタリング

### 特定のタグキーを持つインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters "Name=tag-key,Values=Environment"
```

### 特定のタグ値を持つインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production"
```

### 複数のタグ値で取得

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production,Staging"
```

### Nameタグによる取得

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-server-01"
```

### ワイルドカードを使用したタグフィルタ

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-*"
```

## アベイラビリティゾーンによるフィルタリング

### 特定のAZのインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters "Name=availability-zone,Values=ap-northeast-1a"
```

### 複数のAZで取得

```bash
aws ec2 describe-instances \
  --filters "Name=availability-zone,Values=ap-northeast-1a,ap-northeast-1c"
```

## --query オプションによるJMESPath フィルタリング

### インスタンスIDのみを取得

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text
```

### インスタンスIDとステータスを取得

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table
```

### 特定フィールドをテーブル形式で取得

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress]' \
  --output table
```

### Nameタグとパブリック/プライベートIPを取得

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
  --output table
```

### 実行中のインスタンスのみをクエリでフィルタ

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType]' \
  --output table
```

### t2インスタンスのみをクエリでフィルタ

```bash
aws ec2 describe-instances \
  --query "Reservations[].Instances[?starts_with(InstanceType, 't2')].[InstanceId,InstanceType]" \
  --output table
```

## 複数フィルタの組み合わせ

### 実行中のt2.microインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=instance-type,Values=t2.micro"
```

### 特定環境の実行中インスタンスを取得

```bash
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=tag:Environment,Values=Production"
```

### 特定AZの特定タイプで実行中のインスタンスを取得

```bash
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=instance-type,Values=t2.micro,t2.small" \
    "Name=availability-zone,Values=ap-northeast-1a"
```

### プロジェクトと環境タグで絞り込み

```bash
aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=MyApp" \
    "Name=tag:Environment,Values=Production" \
    "Name=instance-state-name,Values=running"
```

## ページネーション

### デフォルトのページサイズで取得

```bash
aws ec2 describe-instances --max-items 10
```

### 次のページを取得

```bash
aws ec2 describe-instances \
  --max-items 10 \
  --starting-token <token-from-previous-response>
```

### ページサイズを指定

```bash
aws ec2 describe-instances --page-size 50
```

## 実践的なフィルタリングシナリオ

### シナリオ1: Nameタグでインスタンスを検索

```bash
# 特定の名前のインスタンスを検索
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-server-01" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' \
  --output table
```

```bash
# 名前パターンで検索
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name]' \
  --output table
```

### シナリオ2: IPアドレスを取得

```bash
# すべての実行中インスタンスのパブリックIPを取得
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
  --output text
```

```bash
# プライベートIPアドレスのみを取得
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PrivateIpAddress' \
  --output text
```

```bash
# NameタグとIP情報を整形して表示
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress,InstanceType]' \
  --output table
```

### シナリオ3: 環境タグでインスタンスをリスト

```bash
# Production環境のすべてのインスタンス
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Production" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,State.Name]' \
  --output table
```

```bash
# Development環境の実行中インスタンス
aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=Development" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,PrivateIpAddress]' \
  --output table
```

```bash
# 環境別にカウント
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Environment`].Value|[0]]' \
  --output text | sort | uniq -c
```

### シナリオ4: プロジェクトタグでインスタンスをリスト

```bash
# 特定プロジェクトのインスタンス一覧
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=MyWebApp" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,Tags[?Key==`Environment`].Value|[0]]' \
  --output table
```

```bash
# プロジェクトと環境で絞り込み
aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=MyWebApp" \
    "Name=tag:Environment,Values=Production" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,PublicIpAddress]' \
  --output table
```

### シナリオ5: コスト管理のためのインスタンス一覧

```bash
# インスタンスタイプ別にグループ化
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceType,InstanceId]' \
  --output text | sort | uniq -c
```

```bash
# 特定タイプの実行中インスタンス数
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=instance-type,Values=t2.micro" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | wc -w
```

### シナリオ6: セキュリティグループでフィルタ

```bash
# 特定のセキュリティグループを使用しているインスタンス
aws ec2 describe-instances \
  --filters "Name=instance.group-name,Values=web-server-sg" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table
```

```bash
# セキュリティグループIDでフィルタ
aws ec2 describe-instances \
  --filters "Name=instance.group-id,Values=sg-0123456789abcdef0" \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' \
  --output table
```

### シナリオ7: VPCとサブネットでフィルタ

```bash
# 特定VPCのインスタンス
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=vpc-0123456789abcdef0" \
  --query 'Reservations[].Instances[].[InstanceId,SubnetId,PrivateIpAddress]' \
  --output table
```

```bash
# 特定サブネットのインスタンス
aws ec2 describe-instances \
  --filters "Name=subnet-id,Values=subnet-0123456789abcdef0" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress]' \
  --output table
```

### シナリオ8: 起動時刻でフィルタ

```bash
# 起動時刻を含む詳細情報
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,LaunchTime]' \
  --output table
```

```bash
# 起動時刻でソート（最新順）
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[] | sort_by(@, &LaunchTime) | reverse(@).[Tags[?Key==`Name`].Value|[0],InstanceId,LaunchTime]' \
  --output table
```

### シナリオ9: 複雑なクエリの組み合わせ

```bash
# 実行中のt2/t3インスタンスでProduction環境のもの
aws ec2 describe-instances \
  --filters \
    "Name=instance-state-name,Values=running" \
    "Name=tag:Environment,Values=Production" \
  --query "Reservations[].Instances[?starts_with(InstanceType, 't2') || starts_with(InstanceType, 't3')].[Tags[?Key==\`Name\`].Value|[0],InstanceId,InstanceType,PublicIpAddress]" \
  --output table
```

```bash
# パブリックIPを持つインスタンスのみ
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?PublicIpAddress!=`null`].[Tags[?Key==`Name`].Value|[0],InstanceId,PublicIpAddress]' \
  --output table
```

### シナリオ10: CSV形式で出力

```bash
# CSV形式でエクスポート
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output text | awk '{print $1","$2","$3","$4","$5","$6}'
```

## 詳細なフィルタ例

### よく使用されるフィルタ一覧

| フィルタ名 | 説明 | 例 |
|-----------|------|-----|
| `instance-state-name` | インスタンスの状態 | `running`, `stopped` |
| `instance-type` | インスタンスタイプ | `t2.micro`, `t3.small` |
| `availability-zone` | アベイラビリティゾーン | `ap-northeast-1a` |
| `tag:Key` | 特定のタグキー | `tag:Name`, `tag:Environment` |
| `tag-key` | タグキーの存在 | `Name`, `Environment` |
| `vpc-id` | VPC ID | `vpc-0123456789abcdef0` |
| `subnet-id` | サブネット ID | `subnet-0123456789abcdef0` |
| `instance.group-id` | セキュリティグループ ID | `sg-0123456789abcdef0` |
| `instance.group-name` | セキュリティグループ名 | `web-server-sg` |
| `private-ip-address` | プライベートIP | `10.0.1.10` |
| `ip-address` | パブリックIP | `54.123.45.67` |
| `architecture` | アーキテクチャ | `x86_64`, `arm64` |
| `image-id` | AMI ID | `ami-0123456789abcdef0` |
| `key-name` | キーペア名 | `my-key-pair` |

### アーキテクチャでフィルタ

```bash
# ARM64インスタンスを検索
aws ec2 describe-instances \
  --filters "Name=architecture,Values=arm64" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Architecture]' \
  --output table
```

### キーペアでフィルタ

```bash
# 特定のキーペアを使用しているインスタンス
aws ec2 describe-instances \
  --filters "Name=key-name,Values=my-production-key" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],KeyName]' \
  --output table
```

### AMI IDでフィルタ

```bash
# 特定のAMIから起動されたインスタンス
aws ec2 describe-instances \
  --filters "Name=image-id,Values=ami-0123456789abcdef0" \
  --query 'Reservations[].Instances[].[InstanceId,ImageId,LaunchTime]' \
  --output table
```

### IPアドレスでフィルタ

```bash
# 特定のプライベートIPアドレスを持つインスタンス
aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=10.0.1.10" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress]' \
  --output table
```

## スクリプトでの活用例

### 実行中インスタンスの一括停止

```bash
#!/bin/bash

# Development環境の実行中インスタンスを取得して停止
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=Development" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Stopping instances: $INSTANCE_IDS"
  aws ec2 stop-instances --instance-ids $INSTANCE_IDS
else
  echo "No running instances found"
fi
```

### インベントリレポート生成

```bash
#!/bin/bash

# すべての実行中インスタンスのインベントリを生成
echo "Name,InstanceId,Type,State,PublicIP,PrivateIP,Environment,Project"

aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[
    Tags[?Key==`Name`].Value|[0],
    InstanceId,
    InstanceType,
    State.Name,
    PublicIpAddress,
    PrivateIpAddress,
    Tags[?Key==`Environment`].Value|[0],
    Tags[?Key==`Project`].Value|[0]
  ]' \
  --output text | awk '{print $1","$2","$3","$4","$5","$6","$7","$8}'
```

### ヘルスチェックスクリプト

```bash
#!/bin/bash

# 特定プロジェクトの実行中インスタンスをチェック
echo "Checking instances for Project: MyWebApp"

aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=MyWebApp" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[
    Tags[?Key==`Name`].Value|[0],
    InstanceId,
    State.Name,
    PublicIpAddress
  ]' \
  --output table
```

## トラブルシューティング

### フィルタが機能しない場合

```bash
# 1. タグのキー名を確認
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[].Instances[].Tags'

# 2. 正確なフィルタ名を確認
aws ec2 describe-instances help | grep -A 5 "filters"
```

### 結果が空の場合

```bash
# すべてのインスタンスを取得してフィルタを段階的に追加
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'

# 特定のフィルタのみを追加
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId'
```

## ベストプラクティス

1. **複数フィルタの使用**: サーバー側でフィルタリングすることで、転送データ量を削減
2. **--query の活用**: 必要な情報のみを抽出してパフォーマンスを向上
3. **タグ規則の統一**: 一貫したタグ付け規則により、フィルタリングが容易に
4. **出力形式の選択**: 用途に応じて `table`, `json`, `text` を使い分け
5. **スクリプト化**: 頻繁に使用するクエリはスクリプトに保存

## 関連コマンド

- `aws ec2 describe-instance-status` - インスタンスのステータスチェック
- `aws ec2 describe-tags` - タグ情報の取得
- `aws ec2 describe-vpcs` - VPC情報の取得
- `aws ec2 describe-subnets` - サブネット情報の取得
- `aws ec2 describe-security-groups` - セキュリティグループ情報の取得
