# Discord Chatbot on AWS EC2

## 概要

Discord Bot（エコーボット）をAWS EC2インスタンス上にデプロイするTerraform構成です。メンションされたメッセージをエコーバックするシンプルなボットが、systemdサービスとして24時間365日常時稼働します。S3、Secrets Manager、User Dataスクリプトによる完全自動セットアップを実現しており、SSH接続しての手動設定は不要です。

> **📖 詳細な全体像は [BIG_PICTURE.md](BIG_PICTURE.md) を参照してください**

### 技術スタック

- **IaC**: Terraform
- **インフラ**: AWS (EC2, S3, Secrets Manager, VPC, Security Groups, IAM)
- **OS**: Amazon Linux 2023
- **言語**: Python 3.11
- **ライブラリ**: discord.py, boto3
- **プロセス管理**: systemd

### 作成物

Discordサーバーに招待したBotに対して `@BotName メッセージ` の形式でメンションすると、Botが同じメッセージをエコーバックします。EC2インスタンス上で常時稼働し、プロセスやインスタンスが再起動しても自動的に復旧します。Bot Tokenは AWS Secrets Manager で安全に管理され、Botのコード自体はS3バケットで一元管理されます
## 構成ファイル

### Terraform構成ファイル

- **provider.tf**: AWSプロバイダーの設定（リージョン、認証情報）
- **variables.tf**: 全変数の定義（型、バリデーション、説明）
- **dev.tfvars**: 開発環境用の変数値（リージョン、インスタンスタイプ、SSH許可IP等）
- **main.tf**: EC2インスタンス、AMI取得、SSH鍵ペア作成
- **s3.tf**: Botスクリプト保管用S3バケット（バージョニング有効化）
- **secrets.tf**: Discord Bot Token保管用Secrets Manager
- **security_groups.tf**: SSH、HTTPSのセキュリティグループルール
- **iam.tf**: EC2用IAMロールとポリシー（S3、Secrets Manager、SSM、CloudWatch）
- **outputs.tf**: デプロイ後の出力値（IP、DNS、SSH接続コマンド）

### アプリケーションファイル

- **python/echo.py**: Discord Botのメインスクリプト（S3にアップロードして使用）
- **user_data.sh**: EC2初回起動時の自動セットアップスクリプト（パッケージインストール、S3/Secrets Manager連携、systemdサービス登録）

## コードの特徴

### 1. 完全自動化されたデプロイフロー

従来のEC2デプロイでは、インスタンス起動後にSSH接続してファイルをコピーし、手動で設定する必要がありました。本プロジェクトでは、**User Dataスクリプト**、**S3**、**Secrets Manager**を組み合わせることで、`terraform apply`実行後に自動的にBotが起動する仕組みを実現しています。

```bash
# user_data.shの主要な処理フロー
1. Python 3.11とpipのインストール
2. discord.py、boto3ライブラリのインストール
3. S3から最新のecho.pyをダウンロード
4. Secrets ManagerからBot Tokenを取得して環境変数化
5. systemdサービスの作成と自動起動設定
6. サービスの起動とログ記録
```

### 2. セキュアな認証情報管理

Discord Bot TokenをコードやEC2インスタンスに直接埋め込むことなく、**AWS Secrets Manager**で暗号化管理しています。EC2インスタンスは**IAMロール**経由でSecrets Managerにアクセスするため、アクセスキーやシークレットキーを保存する必要がありません。

```python
# echo.pyでのSecrets Manager連携例
import boto3
import json

client = boto3.client('secretsmanager')
response = client.get_secret_value(SecretId='discord-bot-dev-token')
secret = json.loads(response['SecretString'])
TOKEN = secret['DISCORD_BOT_TOKEN']
```

### 3. S3によるコード管理とバージョニング

Botスクリプト（echo.py）をS3バケットで管理することで、以下のメリットがあります：

- **バージョン管理**: S3バージョニングにより、過去のコードにロールバック可能
- **一元管理**: 複数のEC2インスタンスで同じコードを共有可能
- **簡単な更新**: S3にアップロード→サービス再起動だけでコード更新完了

### 4. systemdによる自動起動・再起動

Botをsystemdサービスとして登録することで、以下を実現：

- **自動起動**: EC2インスタンス起動時に自動でBotが起動
- **自動再起動**: プロセスがクラッシュしても自動的に再起動（`Restart=always`）
- **ログ管理**: journalctlでログを一元管理

### 5. 最小権限の原則に基づくIAM設計

EC2インスタンスに付与されるIAMロールは、必要最小限の権限のみを持ちます：

```hcl
# S3アクセス: 特定バケット内のecho.pyのみ読み取り可能
"Action": ["s3:GetObject"]
"Resource": "arn:aws:s3:::${bucket_name}/echo.py"

# Secrets Manager: 特定シークレットのみ読み取り可能
"Action": ["secretsmanager:GetSecretValue"]
"Resource": "${secret_arn}"
```

## 注意事項

### セキュリティ関連

1. **SSH接続IPの制限**: `dev.tfvars`の`my_ip`を必ず自分のIPアドレス（`xxx.xxx.xxx.xxx/32`）に変更してください。デフォルトの`0.0.0.0/0`は全世界からのアクセスを許可するため危険です。

2. **Discord Bot Tokenの管理**: 
   - Bot Tokenは環境変数`TF_VAR_discord_bot_token`で設定します
   - Tokenは絶対にGitにコミットしないでください
   - Tokenが漏洩した場合は、即座にDiscord Developer PortalでTokenをリセットしてください

3. **SSH秘密鍵の保護**:
   - 生成したSSH秘密鍵（`discord-bot-key`）は`.gitignore`に含まれています
   - パーミッションを`chmod 600`に設定してください
   - 安全な場所にバックアップを取ってください

### コスト関連

- **EC2 t2.micro**: AWS無料利用枠（月750時間）の対象ですが、無料枠を超えた場合は課金されます
- **S3**: 保存容量は数KB程度ですが、リクエスト数に応じて課金される可能性があります
- **Secrets Manager**: シークレット1個あたり月額$0.40の費用がかかります
- 使用後は`terraform destroy`で全リソースを削除することで課金を停止できます

### デプロイ前の準備

1. **AWS CLI**: インストール済みで認証設定完了が必要
2. **Terraform**: バージョン1.0.0以上推奨
3. **Discord Bot**: Discord Developer Portalでトークン取得済み
4. **SSH鍵ペア**: RSA 4096ビット以上を推奨

### 主要なデプロイ手順

1. **Discord Bot Tokenを環境変数に設定**
   ```bash
   export TF_VAR_discord_bot_token="YOUR_DISCORD_BOT_TOKEN_HERE"
   ```

2. **SSH鍵ペアを生成**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ./discord-bot-key
   chmod 600 discord-bot-key
   ```

3. **dev.tfvarsを編集（自分のIPアドレスを設定）**
   ```bash
   my_ip = "203.0.113.45/32"  # 自分のIPに変更
   ```

4. **Terraformでデプロイ**
   ```bash
   terraform init
   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

5. **BotスクリプトをS3にアップロード**
   ```bash
   aws s3 cp python/echo.py s3://$(terraform output -raw s3_bucket_name)/echo.py
   ```

6. **SSH接続してBotの状態を確認**
   ```bash
   ssh -i ./discord-bot-key ec2-user@<公開IP>
   sudo journalctl -u discord-bot -f
   ```

詳細な手順やトラブルシューティングについては、プロジェクト内の詳細ドキュメントを参照してください。

---

## リソースのクリーンアップ

```bash
terraform destroy -var-file="dev.tfvars"
```

---

## 参考リンク

- [Discord Developer Portal](https://discord.com/developers/applications)
- [discord.py Documentation](https://discordpy.readthedocs.io/)