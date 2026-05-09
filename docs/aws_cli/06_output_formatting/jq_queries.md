# jq クエリ実践

## 目次
- [jqとは](#jqとは)
- [基本操作](#基本操作)
- [フィルタリング](#フィルタリング)
- [変換と整形](#変換と整形)
- [高度なクエリ](#高度なクエリ)
- [実践的な例](#実践的な例)

## jqとは

jqはコマンドラインのJSON プロセッサーで、AWS CLIの出力を柔軟に処理できます。

### インストール
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# バージョン確認
jq --version
```

### 基本的な使い方
```bash
# 整形表示
aws ec2 describe-instances --output json | jq '.'

# ファイルから読み込み
jq '.' data.json

# コンパクト出力
aws ec2 describe-instances --output json | jq -c '.'

# Raw出力（クォートなし）
aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output json | jq -r '.'
```

## 基本操作

### フィールドアクセス
```bash
# トップレベルのフィールド
aws s3api list-buckets --output json | jq '.Buckets'

# ネストしたフィールド
aws ec2 describe-instances --output json | jq '.Reservations[0].Instances[0].InstanceId'

# オプショナルフィールド（存在しない場合はnull）
aws ec2 describe-instances --output json | jq '.Reservations[0].Instances[0].PublicIpAddress?'
```

### 配列操作
```bash
# すべての要素
aws s3api list-buckets --output json | jq '.Buckets[]'

# 特定の位置
aws s3api list-buckets --output json | jq '.Buckets[0]'

# 最後の要素
aws s3api list-buckets --output json | jq '.Buckets[-1]'

# スライス
aws s3api list-buckets --output json | jq '.Buckets[0:3]'

# 配列の長さ
aws s3api list-buckets --output json | jq '.Buckets | length'
```

### オブジェクト構築
```bash
# 新しいオブジェクトを構築
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  type: .InstanceType,
  state: .State.Name
}'

# 複数フィールドを結合
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  name: (.Tags[] | select(.Key == "Name") | .Value),
  info: "\(.InstanceType) in \(.Placement.AvailabilityZone)"
}'
```

## フィルタリング

### select関数
```bash
# 条件でフィルタ
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | select(.State.Name == "running")'

# 複数条件（AND）
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | 
  select(.State.Name == "running" and .InstanceType == "t3.micro")'

# 複数条件（OR）
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | 
  select(.State.Name == "running" or .State.Name == "stopped")'

# 否定
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | 
  select(.State.Name != "terminated")'
```

### 比較演算子
```bash
# 数値比較
aws ec2 describe-volumes --output json | jq '.Volumes[] | select(.Size > 100)'

aws ec2 describe-volumes --output json | jq '.Volumes[] | select(.Size >= 100 and .Size <= 500)'

# 文字列マッチング
aws s3api list-buckets --output json | jq '.Buckets[] | select(.Name | startswith("prod-"))'

aws s3api list-buckets --output json | jq '.Buckets[] | select(.Name | endswith("-backup"))'

aws s3api list-buckets --output json | jq '.Buckets[] | select(.Name | contains("log"))'

# 正規表現
aws s3api list-buckets --output json | jq '.Buckets[] | select(.Name | test("^prod-.*-\\d{4}$"))'
```

### 存在チェック
```bash
# フィールドが存在するか
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | select(has("PublicIpAddress"))'

# null/空チェック
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | select(.PublicIpAddress != null)'

# 配列が空でない
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | select(.Tags | length > 0)'
```

## 変換と整形

### map関数
```bash
# 配列の各要素に関数を適用
aws s3api list-buckets --output json | jq '.Buckets | map(.Name)'

# 複雑な変換
aws ec2 describe-instances --output json | jq '.Reservations[].Instances | map({
  id: .InstanceId,
  type: .InstanceType,
  state: .State.Name
})'

# map + select
aws ec2 describe-instances --output json | jq '.Reservations[].Instances | 
  map(select(.State.Name == "running")) | 
  map({id: .InstanceId, type: .InstanceType})'
```

### group_by関数
```bash
# インスタンスタイプでグループ化
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[]] | 
  group_by(.InstanceType) | 
  map({
    type: .[0].InstanceType,
    count: length,
    instances: map(.InstanceId)
  })'

# ステータスでグループ化
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[]] | 
  group_by(.State.Name) | 
  map({
    state: .[0].State.Name,
    count: length
  })'
```

### sort_by関数
```bash
# 単一フィールドでソート
aws s3api list-buckets --output json | jq '.Buckets | sort_by(.CreationDate)'

# 逆順ソート
aws s3api list-buckets --output json | jq '.Buckets | sort_by(.CreationDate) | reverse'

# 複数フィールドでソート
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[]] | 
  sort_by(.InstanceType, .LaunchTime)'
```

### unique関数
```bash
# 重複を削除
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[].InstanceType] | unique'

# unique_by
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[]] | unique_by(.InstanceType)'
```

### 文字列操作
```bash
# 大文字・小文字変換
echo '{"name": "Hello World"}' | jq '.name | ascii_upcase'
echo '{"name": "Hello World"}' | jq '.name | ascii_downcase'

# 分割
echo '{"path": "a/b/c/d"}' | jq '.path | split("/")'

# 結合
echo '["a","b","c"]' | jq 'join("-")'

# 置換
echo '{"text": "hello world"}' | jq '.text | gsub("world"; "jq")'

# トリム
echo '{"text": "  hello  "}' | jq '.text | ltrimstr(" ") | rtrimstr(" ")'
```

### 数値計算
```bash
# 合計
aws ec2 describe-volumes --output json | jq '[.Volumes[].Size] | add'

# 平均
aws ec2 describe-volumes --output json | jq '[.Volumes[].Size] | add / length'

# 最大・最小
aws ec2 describe-volumes --output json | jq '[.Volumes[].Size] | max'
aws ec2 describe-volumes --output json | jq '[.Volumes[].Size] | min'

# カウント
aws ec2 describe-instances --output json | jq '[.Reservations[].Instances[]] | length'
```

## 高度なクエリ

### 条件分岐
```bash
# if-then-else
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  status: (if .State.Name == "running" then "active" else "inactive" end)
}'

# 複数条件
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  size: (
    if .InstanceType | startswith("t3.nano") then "xs"
    elif .InstanceType | startswith("t3.micro") then "s"
    elif .InstanceType | startswith("t3.small") then "m"
    else "l"
    end
  )
}'
```

### try-catch
```bash
# エラーハンドリング
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  publicIp: (.PublicIpAddress // "N/A")
}'

# try演算子
aws ec2 describe-instances --output json | jq '.Reservations[].Instances[] | {
  id: .InstanceId,
  name: (try (.Tags[] | select(.Key == "Name") | .Value) catch "Unnamed")
}'
```

### 再帰処理
```bash
# すべてのネストした値を取得
aws cloudformation describe-stacks --output json | jq '.. | select(type == "string")'

# 特定のキーを再帰的に検索
aws ec2 describe-instances --output json | jq '.. | .InstanceId? | select(. != null)'
```

### カスタム関数
```bash
# 関数定義
aws ec2 describe-instances --output json | jq '
  def get_name: .Tags[] | select(.Key == "Name") | .Value;
  .Reservations[].Instances[] | {
    id: .InstanceId,
    name: (try get_name catch "N/A")
  }
'

# 複数の関数
aws ec2 describe-instances --output json | jq '
  def get_tag($key): .Tags[] | select(.Key == $key) | .Value;
  def format_info: "\(.InstanceType) in \(.Placement.AvailabilityZone)";
  
  .Reservations[].Instances[] | {
    id: .InstanceId,
    name: (try get_tag("Name") catch "N/A"),
    env: (try get_tag("Environment") catch "N/A"),
    info: format_info
  }
'
```

### 変数の使用
```bash
# 変数定義
aws ec2 describe-instances --output json | jq '
  .Reservations[].Instances[] as $instance |
  $instance.Tags[] |
  select(.Key == "Name") |
  {
    instance_id: $instance.InstanceId,
    name: .Value
  }
'

# 複数変数
aws cloudformation describe-stacks --output json | jq '
  .Stacks[0] as $stack |
  $stack.Outputs[] |
  {
    stack_name: $stack.StackName,
    output_key: .OutputKey,
    output_value: .OutputValue
  }
'
```

## 実践的な例

### インスタンス情報の整形
```bash
#!/bin/bash
# format-instances.sh - インスタンス情報を見やすく整形

aws ec2 describe-instances --output json | jq -r '
  .Reservations[].Instances[] |
  select(.State.Name != "terminated") |
  {
    id: .InstanceId,
    name: (try (.Tags[] | select(.Key == "Name") | .Value) catch "N/A"),
    type: .InstanceType,
    state: .State.Name,
    az: .Placement.AvailabilityZone,
    private_ip: (.PrivateIpAddress // "N/A"),
    public_ip: (.PublicIpAddress // "N/A"),
    launch_time: .LaunchTime
  } |
  "\(.id)\t\(.name)\t\(.type)\t\(.state)\t\(.az)\t\(.private_ip)\t\(.public_ip)\t\(.launch_time)"
' | column -t -s $'\t'
```

### タグ情報の抽出
```bash
#!/bin/bash
# extract-tags.sh - すべてのタグを構造化して抽出

aws ec2 describe-instances --output json | jq '
  [.Reservations[].Instances[]] |
  map({
    instance_id: .InstanceId,
    tags: (
      .Tags | 
      map({(.Key): .Value}) | 
      add // {}
    )
  })
'
```

### コスト分析レポート
```bash
#!/bin/bash
# cost-analysis.sh - リソースタイプ別の集計

echo "=== EC2 Instance Types ==="
aws ec2 describe-instances --output json | jq -r '
  [.Reservations[].Instances[] | select(.State.Name != "terminated")] |
  group_by(.InstanceType) |
  map({
    type: .[0].InstanceType,
    count: length,
    instance_ids: map(.InstanceId)
  }) |
  sort_by(.count) |
  reverse |
  .[] |
  "\(.type): \(.count) instances"
'

echo ""
echo "=== EBS Volume Summary ==="
aws ec2 describe-volumes --output json | jq -r '
  {
    total_volumes: (.Volumes | length),
    total_size_gb: ([.Volumes[].Size] | add),
    by_type: (
      .Volumes |
      group_by(.VolumeType) |
      map({
        type: .[0].VolumeType,
        count: length,
        total_size: ([.[].Size] | add)
      })
    )
  } |
  "Total Volumes: \(.total_volumes)",
  "Total Size: \(.total_size_gb) GB",
  "",
  "By Type:",
  (.by_type[] | "  \(.type): \(.count) volumes, \(.total_size) GB")
'
```

### セキュリティ監査
```bash
#!/bin/bash
# security-audit.sh - セキュリティ設定を確認

echo "=== Security Groups with 0.0.0.0/0 ==="
aws ec2 describe-security-groups --output json | jq -r '
  .SecurityGroups[] |
  select(
    .IpPermissions[] |
    .IpRanges[] |
    .CidrIp == "0.0.0.0/0"
  ) |
  {
    group_id: .GroupId,
    group_name: .GroupName,
    vpc_id: .VpcId,
    open_ports: [
      .IpPermissions[] |
      select(.IpRanges[] | .CidrIp == "0.0.0.0/0") |
      if .FromPort == .ToPort then
        "\(.IpProtocol):\(.FromPort)"
      else
        "\(.IpProtocol):\(.FromPort)-\(.ToPort)"
      end
    ]
  } |
  "Group: \(.group_name) (\(.group_id))",
  "VPC: \(.vpc_id)",
  "Open Ports: \(.open_ports | join(", "))",
  ""
'

echo "=== Instances without Name Tag ==="
aws ec2 describe-instances --output json | jq -r '
  [.Reservations[].Instances[]] |
  map(
    select(.State.Name != "terminated") |
    select((.Tags // []) | map(.Key) | contains(["Name"]) | not)
  ) |
  .[] |
  .InstanceId
'
```

### CloudFormation スタック情報
```bash
#!/bin/bash
# stack-info.sh - スタック情報を詳細に表示

STACK_NAME="$1"

if [ -z "$STACK_NAME" ]; then
  echo "Usage: $0 <stack-name>"
  exit 1
fi

aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --output json | jq -r '
  .Stacks[0] |
  "Stack Name: \(.StackName)",
  "Status: \(.StackStatus)",
  "Created: \(.CreationTime)",
  "",
  "Parameters:",
  (.Parameters[] | "  \(.ParameterKey): \(.ParameterValue)"),
  "",
  "Outputs:",
  (.Outputs[] | "  \(.OutputKey): \(.OutputValue)"),
  "",
  "Tags:",
  (.Tags[] | "  \(.Key): \(.Value)")
'
```

### JSON to CSV変換
```bash
#!/bin/bash
# json-to-csv.sh - JSON形式のAWS CLI出力をCSVに変換

aws ec2 describe-instances --output json | jq -r '
  (["InstanceId","Name","Type","State","PrivateIP","PublicIP","AZ"] | @csv),
  (.Reservations[].Instances[] |
    [
      .InstanceId,
      (try (.Tags[] | select(.Key == "Name") | .Value) catch ""),
      .InstanceType,
      .State.Name,
      (.PrivateIpAddress // ""),
      (.PublicIpAddress // ""),
      .Placement.AvailabilityZone
    ] | @csv
  )
' > instances.csv

echo "CSV exported to instances.csv"
```

### リアルタイム監視
```bash
#!/bin/bash
# monitor-instances.sh - インスタンスの状態をリアルタイム監視

watch -n 5 '
  aws ec2 describe-instances --output json | jq -r "
    [.Reservations[].Instances[]] |
    group_by(.State.Name) |
    map({
      state: .[0].State.Name,
      count: length
    }) |
    .[] |
    \"\(.state): \(.count)\"
  "
'
```

### 複雑なフィルタリング
```bash
#!/bin/bash
# complex-filter.sh - 複雑な条件でリソースを抽出

aws ec2 describe-instances --output json | jq '
  [.Reservations[].Instances[]] |
  map(
    select(
      .State.Name == "running" and
      (.Tags // [] | map(select(.Key == "Environment" and .Value == "Production")) | length > 0) and
      (.InstanceType | startswith("t3."))
    )
  ) |
  map({
    id: .InstanceId,
    name: (try (.Tags[] | select(.Key == "Name") | .Value) catch "N/A"),
    type: .InstanceType,
    environment: (.Tags[] | select(.Key == "Environment") | .Value),
    cost_center: (try (.Tags[] | select(.Key == "CostCenter") | .Value) catch "Unassigned")
  }) |
  group_by(.cost_center) |
  map({
    cost_center: .[0].cost_center,
    instance_count: length,
    instances: map({id: .id, name: .name, type: .type})
  })
'
```

### マージと結合
```bash
#!/bin/bash
# merge-data.sh - 複数のAWS CLIコマンドの結果をマージ

# インスタンス情報を取得
INSTANCES=$(aws ec2 describe-instances --output json)

# ボリューム情報を取得
VOLUMES=$(aws ec2 describe-volumes --output json)

# jqで結合
jq -n \
  --argjson instances "$INSTANCES" \
  --argjson volumes "$VOLUMES" '
  $instances.Reservations[].Instances[] as $instance |
  {
    instance_id: $instance.InstanceId,
    instance_type: $instance.InstanceType,
    volumes: [
      $volumes.Volumes[] |
      select(
        .Attachments[] |
        .InstanceId == $instance.InstanceId
      ) |
      {
        volume_id: .VolumeId,
        size: .Size,
        type: .VolumeType
      }
    ]
  }
'
```

このドキュメントでは、jqを使った高度なJSON処理を説明しました。AWS CLIと組み合わせることで、複雑なデータ処理を効率的に行えます。
