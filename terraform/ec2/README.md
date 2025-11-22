# EC2 Instance Terraform Configuration

このディレクトリには、Amazon EC2インスタンスをデプロイするためのTerraformコードが含まれています。

## 構成

- **provider.tf**: AWSプロバイダーの設定
- **variables.tf**: 変数定義
- **ec2.tf**: EC2インスタンス、セキュリティグループ、IAMロールの定義
- **outputs.tf**: 出力値の定義
- **dev.tfvars**: 開発環境用の変数値
- **prod.tfvars**: 本番環境用の変数値

## 作成されるリソース

1. **EC2インスタンス**
   - Amazon Linux 2023
   - Nginxが自動インストールされる
   - Elastic IPが割り当てられる
   - 暗号化されたgp3ボリューム

2. **セキュリティグループ**
   - SSH (ポート22)
   - HTTP (ポート80)
   - HTTPS (ポート443)

3. **IAMロール**
   - EC2用のIAMロール
   - AWS Systems Manager接続用のポリシー

4. **Elastic IP**
   - 固定IPアドレス

## 使用方法

### 1. 初期化

```bash
terraform init
```

### 2. プランの確認（開発環境）

```bash
terraform plan -var-file="dev.tfvars"
```

### 3. デプロイ（開発環境）

```bash
terraform apply -var-file="dev.tfvars"
```

### 4. リソースの確認

```bash
terraform show
```

### 5. 出力値の確認

```bash
terraform output
```

### 6. リソースの削除

```bash
terraform destroy -var-file="dev.tfvars"
```

## 本番環境へのデプロイ

```bash
# プラン確認
terraform plan -var-file="prod.tfvars"

# デプロイ
terraform apply -var-file="prod.tfvars"
```

## SSH接続

### オプション1: SSH Key Pairを使用する場合

#### 方法A: 新しいSSH鍵ペアを生成してTerraformで登録

1. SSH鍵ペアを生成:

```bash
# デフォルトの場所に生成（~/.ssh/id_rsa）
./scripts/generate_ssh_key.sh

# カスタムの場所に生成
./scripts/generate_ssh_key.sh ~/.ssh my-custom-key
```

2. `dev.tfvars`または`prod.tfvars`で`key_name`を空または未設定のままにする:

```hcl
key_name = ""  # または設定しない
# public_key_pathはデフォルトで~/.ssh/id_rsa.pubを使用
```

3. カスタムパスの公開鍵を使用する場合:

```hcl
key_name = ""
public_key_path = "~/.ssh/my-custom-key.pub"
```

4. デプロイ後、以下のコマンドで接続:

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>
```

#### 方法B: AWS Consoleで作成済みのKey Pairを使用

1. AWS ConsoleでKey Pairを作成
2. `dev.tfvars`または`prod.tfvars`の`key_name`を設定:

```hcl
key_name = "your-existing-key-pair-name"
```

3. デプロイ後、以下のコマンドで接続:

```bash
ssh -i ~/.ssh/your-key-pair-name.pem ec2-user@<PUBLIC_IP>
```

### オプション2: AWS Systems Manager Session Managerを使用する場合（推奨）

SessionManagerPluginが必要。
Key Pairなしで接続可能です:

```bash
aws ssm start-session --target <INSTANCE_ID>
```

### 重要な注意事項

- 秘密鍵は絶対に他人と共有しないでください
- 秘密鍵はGitにコミットしないでください
- `.gitignore`に秘密鍵のパスを追加することを推奨します:
  ```
  *.pem
  id_rsa
  id_rsa.pub
  ```

## カスタマイズ

### インスタンスタイプの変更

`dev.tfvars`または`prod.tfvars`の`instance_type`を変更:

```hcl
instance_type = "t3.medium"
```

### ボリュームサイズの変更

```hcl
root_volume_size = 20
```

### SSH接続元IPの制限

セキュリティ向上のため、`allowed_ssh_cidr`を自分のIPアドレスに制限することを推奨:

```hcl
allowed_ssh_cidr = ["123.456.789.0/32"]  # 自分のIPアドレス
```

## セキュリティ考慮事項

- 本番環境では必ずSSH接続元IPを制限してください
- Key Pairは安全に管理してください
- Session Managerの使用を推奨します（Key Pair不要）
- セキュリティグループのルールは最小権限の原則に従ってください

## トラブルシューティング

### インスタンスに接続できない

1. セキュリティグループの設定を確認
2. Elastic IPが正しく割り当てられているか確認
3. SSH Key Pairが正しいか確認

### Webサーバーにアクセスできない

1. Nginxが起動しているか確認:
   ```bash
   sudo systemctl status nginx
   ```

2. セキュリティグループでポート80/443が開いているか確認

## コスト

- t2.micro: 無料利用枠の対象（750時間/月）
- t3.small: 約$15/月（ap-northeast-1）
- Elastic IP: インスタンスに関連付けられている間は無料
- EBSボリューム: 約$0.12/GB/月
