# EC2 Instance with Ansible Configuration

## 概要
TerraformでEC2インスタンスをプロビジョニングし、Ansibleでアプリケーション設定を行うハイブリッド構成のインフラストラクチャです。Infrastructure as Codeの実践として、インフラ層と設定層を分離し、それぞれに適したツールを使用することで、保守性と再利用性を高めています。

### 技術スタック
- **Terraform** v1.0+ - インフラストラクチャプロビジョニング
- **Ansible** v2.9+ - 構成管理とアプリケーション設定
- **AWS EC2** - コンピューティングリソース
- **Nginx** - Webサーバー
- **Amazon Linux 2023** - OSベースイメージ

### 作成物
デプロイ完了後、固定IPアドレス（Elastic IP）でアクセス可能なWebサーバーが稼働します。Nginxが提供するカスタマイズ可能なWebページにHTTPSでアクセスでき、環境（dev/prod）に応じた異なるコンテンツが表示されます。また、SSH接続とAWS Systems Manager Session Managerの両方でインスタンスへの安全なアクセスが可能です。

## 構成ファイル

### Terraformファイル
- **provider.tf** - AWSプロバイダー設定
- **variables.tf** - 変数定義とデフォルト値
- **data.tf** - AMI、VPCなどのデータソース
- **security_groups.tf** - SSH、HTTP、HTTPSアクセス制御
- **iam.tf** - EC2ロールとSession Managerポリシー
- **keypair.tf** - SSH公開鍵の登録
- **main.tf** - EC2インスタンス、Elastic IP定義
- **user_data.sh** - 起動時のAnsibleインストールスクリプト
- **outputs.tf** - パブリックIP、インスタンスIDの出力
- **dev.tfvars / prod.tfvars** - 環境別変数値

### Ansible構成
- **ansible/playbook.yml** - Nginx設定プレイブック
- **ansible/templates/index.html.j2** - 環境別HTMLテンプレート
- **ansible/ansible.cfg** - SSH設定とホストキー検証
- **ansible/run_playbook.sh** - 実行スクリプト（IP自動取得）

## コードの特徴

### 1. インフラと設定の責務分離
Terraformはインフラのプロビジョニングに専念し、Ansibleはアプリケーションレイヤーの設定を担当。この分離により、インフラの再作成なしにアプリケーション設定を更新でき、CI/CDパイプラインでの段階的デプロイも容易になります。

### 2. user_dataによる動的環境準備
EC2起動時にuser_data.shが実行され、Ansibleを自動インストール。これにより、AMIにAnsibleを事前にベイクする必要がなく、常に最新版のAnsibleを使用できます。

### 3. 環境別設定の柔軟性
tfvarsファイルで環境ごとの設定を分離し、Ansibleテンプレートで環境変数を利用。同一コードベースで開発環境と本番環境を管理でき、設定の一貫性を保ちながら環境差分を明確化しています。

### 4. 複数のアクセス方法をサポート
SSH Key Pair方式とAWS Session Manager方式の両方に対応。Session Managerを使用すれば、SSH鍵管理が不要で、セキュリティグループのSSHポートを閉じることも可能です。

### 5. セキュリティベストプラクティス
- EBSボリュームの暗号化（デフォルト有効）
- IAMロールによる最小権限の付与
- SSH接続元IPの制限機能
- IMDSv2の強制（メタデータサービスのセキュリティ強化）

### 6. 自動化スクリプトによる運用効率化
`ansible/run_playbook.sh`がTerraform outputから自動的にIPアドレスを取得し、SSH接続確認後にAnsibleを実行。手動でのインベントリファイル編集が不要で、ヒューマンエラーを削減します。

## 注意事項

### デプロイ手順
1. **Terraformでインフラをプロビジョニング**: `terraform apply -var-file="dev.tfvars"`
2. **1〜2分待機**: user_dataによるAnsibleインストールが完了するまで待つ
3. **Ansibleで設定適用**: `cd ansible && ./run_playbook.sh dev`

### セキュリティ考慮事項
- 本番環境では`allowed_ssh_cidr`を必ず自分のIPアドレスに制限してください
- SSH秘密鍵は絶対にGitにコミットせず、`.gitignore`に追加してください
- 可能な限りSession Managerの使用を推奨します（SSH鍵管理不要）

### コスト
- **t2.micro**: AWS無料利用枠対象（750時間/月）
- **t3.small**: 約$15/月（ap-northeast-1リージョン）
- **Elastic IP**: 起動中のインスタンスに紐付いている間は無料
- **EBSボリューム**: 約$0.12/GB/月

### トラブルシューティング
- **Ansibleが見つからない**: EC2起動直後の場合、user_dataの実行完了を待ってください
- **SSH接続失敗**: セキュリティグループの設定とElastic IPの割り当てを確認してください
- **Webサーバー接続不可**: Ansibleプレイブックが正常に実行されたか確認し、`sudo systemctl status nginx`でサービス状態をチェックしてください

---

## 使用方法

### 前提条件
- Terraform v1.0+
- Ansible v2.9+
- AWS CLI（認証情報設定済み）
- SSH鍵ペア (~/.ssh/id_rsa)

### 基本的なデプロイフロー

```bash
# 1. 初期化
terraform init

# 2. プランの確認
terraform plan -var-file="dev.tfvars"

# 3. インフラのデプロイ
terraform apply -var-file="dev.tfvars"

# 4. 1〜2分待機（user_dataによるAnsible自動インストール完了まで）

# 5. Ansibleでアプリケーション設定
cd ansible
./run_playbook.sh dev

# 6. Webブラウザでアクセス
# terraform output -raw instance_public_ip で取得したIPにアクセス
```

### リソースの削除

```bash
terraform destroy -var-file="dev.tfvars"
```

### 本番環境へのデプロイ

```bash
terraform apply -var-file="prod.tfvars"
cd ansible && ./run_playbook.sh prod
```
