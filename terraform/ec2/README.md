# EC2 Instance Terraform Configuration

このディレクトリには、Amazon EC2インスタンスをデプロイするためのTerraformコードが含まれています。

## 構成

### Terraformファイル

- **provider.tf**: AWSプロバイダーの設定
- **variables.tf**: 変数定義
- **data.tf**: データソース（AMI、VPC）の定義
- **security_groups.tf**: セキュリティグループの定義
- **iam.tf**: IAMロール、ポリシー、インスタンスプロファイルの定義
- **keypair.tf**: SSH Key Pairの定義
- **main.tf**: EC2インスタンス、Elastic IPの定義
- **user_data.sh**: EC2起動時にAnsibleを事前インストール
- **outputs.tf**: 出力値の定義
- **dev.tfvars**: 開発環境用の変数値
- **prod.tfvars**: 本番環境用の変数値

### Ansible構成

- **ansible/playbook.yml**: Nginx設定用のAnsibleプレイブック
- **ansible/templates/index.html.j2**: HTMLテンプレート
- **ansible/ansible.cfg**: Ansible設定ファイル
- **ansible/inventory.ini**: インベントリファイル（テンプレート）
- **ansible/run_playbook.sh**: Ansible実行スクリプト

## 作成されるリソース

1. **EC2インスタンス**
   - Amazon Linux 2023
   - 起動時にAnsibleが自動インストールされる
   - ローカルからAnsible経由でNginxを設定
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

## アーキテクチャの特徴

### Infrastructure as Code

- **Terraform**: インフラストラクチャのプロビジョニング
- **Ansible**: ローカルからリモート実行で設定管理

### デプロイフロー

1. Terraformがインフラ（EC2、SG、IAM）を作成
2. user_data.shが起動時に実行され、Ansibleをインストール
3. ローカルから`ansible/run_playbook.sh`を実行
4. AnsibleがSSH経由でEC2に接続
5. Nginxがインストール・設定される
6. カスタマイズされたWebページが配信される

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

### 4. Ansibleでアプリケーションをセットアップ

EC2インスタンスが起動したら（1〜2分待つ）、ローカルからAnsibleを実行します：

```bash
# 簡単な方法: 自動スクリプトを使用
cd ansible
./run_playbook.sh dev

# または手動で実行
PUBLIC_IP=$(terraform output -raw instance_public_ip)
ansible-playbook -i "${PUBLIC_IP}," -u ec2-user --private-key ~/.ssh/id_rsa ansible/playbook.yml -e "environment=dev"
```

**注意**: user_dataでAnsibleをインストールするため、EC2起動直後は少し待つ必要があります。

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
# インフラのデプロイ
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"

# Ansibleでアプリケーションセットアップ
cd ansible
./run_playbook.sh prod
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

### Ansibleプレイブックの編集

`ansible/playbook.yml`を編集して、追加のソフトウェアをインストールしたり、設定を変更できます:

```yaml
- name: Install additional packages
  ansible.builtin.dnf:
    name:
      - git
      - docker
    state: present
```

### HTMLテンプレートの変更

`ansible/templates/index.html.j2`を編集して、Webページの内容を変更できます。

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

## 手動でのAnsible実行

### 方法1: 自動スクリプトを使用（推奨）

```bash
cd ansible
./run_playbook.sh dev  # または prod
```

このスクリプトは以下を自動で行います：
- Terraformから公開IPを取得
- SSH接続テスト
- Ansibleプレイブックの実行

### 方法2: 手動でインベントリを編集して実行

```bash
# 1. 公開IPを取得
PUBLIC_IP=$(terraform output -raw instance_public_ip)

# 2. インベントリファイルを編集
# ansible/inventory.ini の <PUBLIC_IP> を実際のIPに置き換える

# 3. Ansibleを実行
cd ansible
ansible-playbook -i inventory.ini playbook.yml -e "environment=dev"
```

### 方法3: SSH経由で直接実行（非推奨）

インスタンス上でAnsibleを実行したい場合：

```bash
# EC2インスタンスにSSH接続
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>

# Ansibleをインストール
sudo pip3 install ansible

# プレイブックをコピーして実行（※localhostモードに変更が必要）
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

1. Ansibleが実行されたか確認:
   ```bash
   cd ansible
   ./run_playbook.sh dev
   ```

2. SSH経由でNginxの状態を確認:
   ```bash
   ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>
   sudo systemctl status nginx
   ```

3. セキュリティグループでポート80/443が開いているか確認

### Ansibleのエラー確認

```bash
# 詳細なログを出力して実行
cd ansible
ansible-playbook -i inventory.ini playbook.yml -e "environment=dev" -vvv

# SSH接続テスト
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP> echo "OK"
```

### Ansibleが見つからない

EC2の起動直後はuser_dataの実行中の可能性があります。1〜2分待ってから再試行してください。

確認方法：
```bash
# user_dataのログを確認
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>
sudo cat /var/log/user-data.log

# Ansibleがインストールされているか確認
ansible --version
```

## ファイル構造の理解

```
terraform/ec2/
├── data.tf                 # データソース（AMI、VPC取得）
├── security_groups.tf      # セキュリティグループ定義
├── iam.tf                  # IAMロール・ポリシー
├── keypair.tf              # SSH Key Pair
├── main.tf                 # EC2インスタンス本体
├── user_data.sh            # 起動時スクリプト（Ansible自動インストール）
├── variables.tf            # 変数定義
├── outputs.tf              # 出力定義
├── provider.tf             # プロバイダー設定
├── dev.tfvars              # 開発環境設定
├── prod.tfvars             # 本番環境設定
└── ansible/
    ├── playbook.yml        # Nginxセットアップ
    ├── ansible.cfg         # Ansible設定
    ├── inventory.ini       # インベントリテンプレート
    ├── run_playbook.sh     # 実行スクリプト（推奨）
    ├── ANSIBLE_GUIDE.md    # Ansible実行ガイド
    └── templates/
        └── index.html.j2   # HTMLテンプレート
```

## 前提条件

ローカル環境に以下がインストールされている必要があります：

- Terraform (>= 1.0)
- Ansible (>= 2.9)
- AWS CLI（認証情報設定済み）
- SSH鍵ペア (~/.ssh/id_rsa)

### Ansibleのインストール

```bash
# macOS
brew install ansible

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install ansible

# Linux (RHEL/CentOS)
sudo yum install ansible
```

## コスト

- t2.micro: 無料利用枠の対象（750時間/月）
- t3.small: 約$15/月（ap-northeast-1）
- Elastic IP: インスタンスに関連付けられている間は無料
- EBSボリューム: 約$0.12/GB/月
