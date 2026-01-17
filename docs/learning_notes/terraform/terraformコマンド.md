Terraformコマンドについて詳しく説明します。

## 主要なTerraformコマンド

### **基本的なワークフロー**

```bash
# 1. 初期化
terraform init

# 2. プランの確認
terraform plan

# 3. 適用
terraform apply

# 4. 削除
terraform destroy
```

## 各コマンドの詳細

### **terraform init**
プロジェクトの初期化を行います。

```bash
# 基本的な使い方
terraform init

# よく使うオプション
terraform init -upgrade           # プロバイダーのバージョンを更新
terraform init -reconfigure       # バックエンドの再設定
terraform init -backend-config=config.tfbackend  # バックエンド設定を外部ファイルから読み込み
```

**使用タイミング:**
- 新しいTerraformプロジェクトを始める時
- `.terraform`ディレクトリを削除した後
- プロバイダーやモジュールを追加・変更した時

### **terraform plan**
実行計画を確認します（実際のリソースは変更しません）。

```bash
# 基本的な使い方
terraform plan

# よく使うオプション
terraform plan -out=planfile      # プランをファイルに保存
terraform plan -var="environment=prod"  # 変数を指定
terraform plan -var-file="prod.tfvars"  # 変数ファイルを指定
terraform plan -target=aws_instance.example  # 特定のリソースのみ対象
terraform plan -refresh=false     # 状態の更新をスキップ
```

**便利な使い方:**
```bash
# 詳細な差分表示
terraform plan -json | jq .

# 特定のリソースのみ確認
terraform plan -target=module.vpc
```

### **terraform apply**
インフラストラクチャの変更を適用します。

```bash
# 基本的な使い方
terraform apply

# よく使うオプション
terraform apply -auto-approve     # 確認プロンプトをスキップ
terraform apply planfile          # 保存したプランを適用
terraform apply -target=aws_instance.example  # 特定のリソースのみ適用
terraform apply -parallelism=10   # 並列実行数を指定（デフォルト10）
terraform apply -var="key=value"  # 変数を指定
```

**実践的な使い方:**
```bash
# CI/CDでよく使うパターン
terraform plan -out=tfplan
terraform apply tfplan

# 特定のモジュールのみ更新
terraform apply -target=module.database
```

### **terraform destroy**
管理しているリソースを削除します。

```bash
# 基本的な使い方
terraform destroy

# よく使うオプション
terraform destroy -auto-approve   # 確認なしで削除
terraform destroy -target=aws_instance.example  # 特定のリソースのみ削除
```

### **terraform state**
状態ファイルを管理します（非常に重要）。

```bash
# 状態の確認
terraform state list              # 管理中のリソース一覧
terraform state show aws_instance.example  # 特定のリソースの詳細

# 状態の操作
terraform state mv aws_instance.old aws_instance.new  # リソースの移動
terraform state rm aws_instance.example  # 状態からリソースを削除（実リソースは残る）
terraform state pull              # リモート状態を取得
terraform state push              # ローカル状態をプッシュ

# インポート
terraform import aws_instance.example i-1234567890  # 既存リソースをインポート
```

**実践例:**
```bash
# リソース名を変更する場合
terraform state mv aws_instance.old_name aws_instance.new_name

# 別のモジュールに移動
terraform state mv module.old.aws_instance.example module.new.aws_instance.example
```

### **terraform fmt**
コードのフォーマットを整えます。

```bash
terraform fmt                     # カレントディレクトリのフォーマット
terraform fmt -recursive          # サブディレクトリも含めて再帰的に
terraform fmt -check              # フォーマットチェックのみ（CI/CDで使用）
terraform fmt -diff               # 変更内容を表示
```

### **terraform validate**
構文チェックを行います。

```bash
terraform validate                # 構文の検証
terraform validate -json          # JSON形式で出力
```

### **terraform output**
出力値を表示します。

```bash
terraform output                  # すべての出力を表示
terraform output instance_ip      # 特定の出力のみ表示
terraform output -json            # JSON形式で出力
terraform output -raw instance_ip # 生の値を出力（引用符なし）
```

**便利な使い方:**
```bash
# 他のスクリプトで使用
INSTANCE_IP=$(terraform output -raw instance_ip)
echo $INSTANCE_IP
```

### **terraform refresh**
状態ファイルを実際のインフラと同期します。

```bash
terraform refresh                 # 状態を更新
```

### **terraform taint / untaint**
リソースを再作成対象としてマークします。

```bash
terraform taint aws_instance.example    # 次回applyで再作成
terraform untaint aws_instance.example  # マークを解除
```

### **terraform workspace**
ワークスペース（環境分離）を管理します。

```bash
terraform workspace list          # ワークスペース一覧
terraform workspace new dev       # 新規作成
terraform workspace select dev    # 切り替え
terraform workspace show          # 現在のワークスペース表示
terraform workspace delete dev    # 削除
```

**実践例:**
```bash
# 環境ごとにワークスペースを作成
terraform workspace new development
terraform workspace new staging
terraform workspace new production

# 環境を切り替えて適用
terraform workspace select production
terraform apply -var-file="production.tfvars"
```

## よく使われる実践的なパターン

### **1. CI/CDパイプライン**
```bash
terraform init -backend-config="bucket=${TF_STATE_BUCKET}"
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### **2. 段階的なリソース作成**
```bash
# VPCのみ作成
terraform apply -target=module.vpc

# データベースを作成
terraform apply -target=module.database

# 最後にすべて適用
terraform apply
```

### **3. 変数を使った環境分離**
```bash
# 開発環境
terraform apply -var-file="dev.tfvars"

# 本番環境
terraform apply -var-file="prod.tfvars"
```

### **4. 既存リソースのインポート**
```bash
# リソースをコードに記述
# main.tf
resource "aws_instance" "imported" {
  # 設定
}

# インポート実行
terraform import aws_instance.imported i-1234567890
```

## よく使う環境変数

```bash
export TF_LOG=DEBUG                    # ログレベル設定
export TF_LOG_PATH=terraform.log       # ログファイル指定
export TF_VAR_region=us-west-2         # 変数の設定
export TF_CLI_ARGS_plan="-parallelism=30"  # コマンド固有の引数
```

## トラブルシューティング用コマンド

```bash
# 状態ファイルの確認
terraform show

# グラフの生成（依存関係の可視化）
terraform graph | dot -Tpng > graph.png

# 状態ファイルのバックアップ
cp terraform.tfstate terraform.tfstate.backup

# ロックの解除（注意して使用）
terraform force-unlock <LOCK_ID>
```

Terraformコマンドで特に知りたい部分や、具体的な使用例について質問があれば教えてください！