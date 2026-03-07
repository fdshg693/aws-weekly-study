# ============================================================================
# Outputs Configuration
# ============================================================================
# このファイルはTerraform適用後に表示される出力値を定義します。
# 出力値はインスタンスへのアクセス方法や重要な情報を提供します。
#
# 出力値の用途:
# 1. デプロイ後の重要な情報を表示
# 2. 他のTerraformモジュールへの情報の受け渡し
# 3. CI/CDパイプラインでの値の取得
# 4. スクリプトやドキュメントの自動生成
#
# 表示方法:
# - terraform apply 後に自動表示
# - terraform output コマンドで再表示
# - terraform output -json でJSON形式で取得
# ============================================================================

# ----------------------------------------------------------------------------
# EC2インスタンスID
# ----------------------------------------------------------------------------
# インスタンスを一意に識別するためのID（例: i-0123456789abcdef0）
#
# 用途:
# - AWS CLIやAPIでインスタンスを操作する際に使用
# - CloudWatchアラームの設定
# - Auto Scalingやタグ付けの自動化
#
# 使用例:
# aws ec2 describe-instances --instance-ids <instance_id>
# aws ec2 start-instances --instance-ids <instance_id>
# aws ec2 stop-instances --instance-ids <instance_id>
output "instance_id" {
  description = "Discord BotのEC2インスタンスID（AWS CLIやAPIでの操作に使用）"
  value       = aws_instance.discord_bot.id
}

# ----------------------------------------------------------------------------
# EC2インスタンスのパブリックIPアドレス
# ----------------------------------------------------------------------------
# インターネットからアクセス可能なIPアドレス
#
# 注意点:
# - インスタンスを停止/起動するとIPアドレスが変わる
# - 固定IPが必要な場合はElastic IPを使用
# - セキュリティグループでアクセス制御が必須
#
# 用途:
# - SSH接続時のホスト名として使用
# - ファイアウォールルールの設定
# - DNSレコードの設定（A レコード）
#
# Elastic IP（固定IP）を使う場合:
# resource "aws_eip" "discord_bot" {
#   instance = aws_instance.discord_bot.id
#   domain   = "vpc"
# }
output "public_ip" {
  description = "Discord BotのEC2インスタンスのパブリックIPアドレス（SSH接続に使用）"
  value       = aws_instance.discord_bot.public_ip
}

# ----------------------------------------------------------------------------
# EC2インスタンスのパブリックDNS名
# ----------------------------------------------------------------------------
# AWSが自動的に割り当てるDNS名
# 形式: ec2-<ip-address>.ap-northeast-1.compute.amazonaws.com
#
# 特徴:
# - IPアドレスに基づいて自動生成される
# - インスタンス停止/起動でIPが変わると、DNS名も変わる
# - リージョンごとに異なるドメイン
#
# 用途:
# - SSH接続時のホスト名（IPアドレスより覚えやすい）
# - 一時的なテスト環境でのアクセス
# - ロードバランサー配下では通常使用しない
#
# 本番環境での推奨:
# - Route 53でカスタムドメインを使用
# - Elastic IPとの組み合わせで永続的なDNS名を設定
output "public_dns" {
  description = "Discord BotのEC2インスタンスのパブリックDNS名"
  value       = aws_instance.discord_bot.public_dns
}

# ----------------------------------------------------------------------------
# プライベートIPアドレス
# ----------------------------------------------------------------------------
# VPC内でのみ有効なIPアドレス
#
# 用途:
# - VPC内の他のリソースからのアクセス
# - プライベートサブネットへの移行時に使用
# - 内部ロードバランサーのターゲット
#
# 特徴:
# - インスタンス停止/起動後も変わらない
# - VPC CIDRの範囲内で割り当てられる
# - セキュリティグループは引き続き適用される
output "private_ip" {
  description = "Discord BotのEC2インスタンスのプライベートIPアドレス（VPC内通信用）"
  value       = aws_instance.discord_bot.private_ip
}

# ----------------------------------------------------------------------------
# 使用しているAMI ID
# ----------------------------------------------------------------------------
# インスタンスが使用しているAmazon Machine ImageのID
#
# 用途:
# - 同じAMIで追加インスタンスを起動
# - 使用しているOSバージョンの確認
# - AMIの更新履歴管理
# - カスタムAMI作成時の基準として使用
output "ami_id" {
  description = "使用しているAmazon Linux 2023のAMI ID"
  value       = aws_instance.discord_bot.ami
}

# ----------------------------------------------------------------------------
# インスタンスタイプ
# ----------------------------------------------------------------------------
# 現在のインスタンスのサイズ（例: t2.micro, t3.small）
#
# 用途:
# - コスト計算
# - パフォーマンスチューニングの参考
# - ドキュメント生成
output "instance_type" {
  description = "EC2インスタンスタイプ"
  value       = aws_instance.discord_bot.instance_type
}

# ----------------------------------------------------------------------------
# セキュリティグループID
# ----------------------------------------------------------------------------
# インスタンスに適用されているセキュリティグループのID
#
# 用途:
# - セキュリティグループルールの確認
# - 他のリソースへの同じセキュリティグループの適用
# - トラブルシューティング
output "security_group_id" {
  description = "適用されているセキュリティグループID"
  value       = aws_security_group.discord_chatbot.id
}

# ----------------------------------------------------------------------------
# SSH接続コマンド
# ----------------------------------------------------------------------------
# EC2インスタンスにSSH接続するためのコマンドを生成
#
# 使用方法:
# 1. terraform output ssh_command をコピー
# 2. ターミナルに貼り付けて実行
#
# 前提条件:
# - 秘密鍵ファイル（discord-bot-key）が~/.sshに存在
# - 秘密鍵のパーミッションが600に設定されている
# - セキュリティグループでSSH（22番ポート）が許可されている
#
# トラブルシューティング:
# - "Permission denied": 秘密鍵のパーミッションを確認（chmod 600）
# - "Connection refused": セキュリティグループのインバウンドルールを確認
# - "Connection timeout": ネットワークACLやルートテーブルを確認
#
# セキュリティ強化オプション:
# - -o StrictHostKeyChecking=yes: ホストキー検証を厳密化
# - -o IdentitiesOnly=yes: 指定した秘密鍵のみを使用
# - -o ServerAliveInterval=60: 接続維持（60秒ごとにキープアライブ）
output "ssh_command" {
  description = "SSH接続コマンド（秘密鍵を使用してインスタンスに接続）"
  value       = "ssh -i ~/.ssh/${var.project_name}-${var.environment}-key ec2-user@${aws_instance.discord_bot.public_ip}"
}

# ----------------------------------------------------------------------------
# AWS Systems Manager Session Manager接続コマンド
# ----------------------------------------------------------------------------
# Session Managerを使用してインスタンスに接続するコマンド
#
# Session Managerの利点:
# 1. SSH鍵不要（IAM認証ベース）
# 2. セキュリティグループでSSHポート開放不要
# 3. 操作ログが自動的にCloudWatch Logsに記録
# 4. ブラウザまたはAWS CLIから接続可能
# 5. プライベートサブネットのインスタンスにも接続可能
#
# 前提条件:
# - AWS CLIがインストールされている
# - Session Manager プラグインがインストールされている
#   インストール方法: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
# - IAMロールでAmazonSSMManagedInstanceCoreポリシーがアタッチされている
# - 適切なIAM権限（ssm:StartSession）がある
#
# 使用方法:
# 1. terraform output session_manager_command をコピー
# 2. ターミナルに貼り付けて実行
#
# ブラウザから接続する方法:
# 1. AWSコンソール > Systems Manager > Session Manager
# 2. "Start session"をクリック
# 3. インスタンスを選択して"Start session"
#
# Session Manager プラグインのインストール:
# macOS: brew install --cask session-manager-plugin
# Ubuntu: curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && sudo dpkg -i session-manager-plugin.deb
# Windows: https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe
output "session_manager_command" {
  description = "AWS Systems Manager Session Managerで接続するコマンド（SSH鍵不要、より安全）"
  value       = "aws ssm start-session --target ${aws_instance.discord_bot.id} --region ${var.aws_region}"
}

# ----------------------------------------------------------------------------
# ユーザーデータログファイルパス
# ----------------------------------------------------------------------------
# user_data.shの実行ログが保存されるパス
#
# 用途:
# - インスタンス初期化の進捗確認
# - エラーのトラブルシューティング
# - セットアップの成功/失敗の確認
#
# ログ確認方法:
# SSH接続後:
#   sudo cat /var/log/user-data.log
#   sudo tail -f /var/log/user-data.log  # リアルタイム監視
#
# Session Manager接続後:
#   cat /var/log/user-data.log
#   tail -f /var/log/user-data.log
#
# よくあるエラーと対処法:
# - "pip: command not found": Python/pip インストール失敗
# - "discord.py installation failed": ネットワーク問題、PyPIへの接続確認
# - "Permission denied": SELinuxやファイルパーミッション問題
output "user_data_log" {
  description = "User Dataスクリプトの実行ログファイルパス"
  value       = "/var/log/user-data.log"
}

# ----------------------------------------------------------------------------
# Discord Botサービスステータス確認コマンド
# ----------------------------------------------------------------------------
# systemdサービスの状態を確認するコマンド
#
# サービス管理コマンド:
# - 状態確認: sudo systemctl status discord-bot
# - 起動: sudo systemctl start discord-bot
# - 停止: sudo systemctl stop discord-bot
# - 再起動: sudo systemctl restart discord-bot
# - 自動起動有効化: sudo systemctl enable discord-bot
# - 自動起動無効化: sudo systemctl disable discord-bot
# - ログ確認: sudo journalctl -u discord-bot -f
#
# トラブルシューティング:
# 1. サービスが起動しない:
#    sudo journalctl -u discord-bot --no-pager
# 2. Pythonエラー:
#    sudo systemctl status discord-bot -l
# 3. 環境変数が読み込まれない:
#    sudo cat /opt/discord-bot/.env
output "service_status_command" {
  description = "Discord Botサービスのステータス確認コマンド"
  value       = "sudo systemctl status discord-bot"
}

# ----------------------------------------------------------------------------
# Discord Bot ログ確認コマンド
# ----------------------------------------------------------------------------
# systemdジャーナルからサービスログを確認
#
# journalctlオプション:
# - -u discord-bot: discord-botサービスのログのみ表示
# - -f: リアルタイムでログを追跡（tail -fと同様）
# - -n 100: 最新100行を表示
# - --since "1 hour ago": 1時間前からのログを表示
# - --until "2023-01-01 12:00": 指定時刻までのログを表示
#
# 使用例:
# 最新100行を表示:
#   sudo journalctl -u discord-bot -n 100
# 
# リアルタイム監視:
#   sudo journalctl -u discord-bot -f
#
# 今日のログのみ:
#   sudo journalctl -u discord-bot --since today
#
# エラーのみ表示:
#   sudo journalctl -u discord-bot -p err
output "service_logs_command" {
  description = "Discord Botサービスのログをリアルタイムで確認するコマンド"
  value       = "sudo journalctl -u discord-bot -f"
}

# ----------------------------------------------------------------------------
# アプリケーションディレクトリパス
# ----------------------------------------------------------------------------
# Discord Botアプリケーションがインストールされているディレクトリ
#
# ディレクトリ構成:
# /opt/discord-bot/
# ├── echo.py          # Botアプリケーション本体
# └── .env             # 環境変数ファイル（DISCORD_BOT_TOKEN）
#
# ファイル編集:
# - Botコードの確認: sudo cat /opt/discord-bot/echo.py
# - 環境変数の設定: sudo vim /opt/discord-bot/.env
# - 権限確認: ls -la /opt/discord-bot/
#
# セキュリティ:
# - .envファイルは600パーミッション（所有者のみ読み書き可能）
# - トークンを含むファイルは適切に保護
output "app_directory" {
  description = "Discord Botアプリケーションのインストールディレクトリ"
  value       = "/opt/discord-bot"
}

# ----------------------------------------------------------------------------
# 初期セットアップ完了後の手順
# ----------------------------------------------------------------------------
# インスタンス作成後に実行すべきステップをまとめて表示
#
# このガイドに従って設定を完了させる
output "next_steps" {
  description = "EC2インスタンス作成後に実行すべき手順"
  value = <<-EOT
  ┌─────────────────────────────────────────────────────────────────┐
  │ Discord Bot セットアップ完了後の手順                            │
  └─────────────────────────────────────────────────────────────────┘
  
  【1】インスタンスに接続
  ────────────────────────────────────────────────────────────
  方法A: SSH接続（鍵ファイルが必要）
    ${format("ssh -i ~/.ssh/%s-%s-key ec2-user@%s", var.project_name, var.environment, aws_instance.discord_bot.public_ip)}
  
  方法B: Session Manager（推奨、鍵不要）
    ${format("aws ssm start-session --target %s --region %s", aws_instance.discord_bot.id, var.aws_region)}
  
  【2】セットアップログを確認（初期化の完了を確認）
  ────────────────────────────────────────────────────────────
    sudo cat /var/log/user-data.log
    # 最後に "セットアップ完了" が表示されていることを確認
  
  【3】Discord Bot Tokenを設定
  ────────────────────────────────────────────────────────────
    sudo vim /opt/discord-bot/.env
    # DISCORD_BOT_TOKEN=your_discord_bot_token_here
    # を実際のトークンに変更して保存
  
    ※ Discord Developer Portalでトークンを取得:
      https://discord.com/developers/applications
  
  【4】Discord Botサービスを再起動
  ────────────────────────────────────────────────────────────
    sudo systemctl restart discord-bot
  
  【5】サービスの動作確認
  ────────────────────────────────────────────────────────────
    sudo systemctl status discord-bot
    # "active (running)" と表示されることを確認
  
  【6】ログを監視（オプション）
  ────────────────────────────────────────────────────────────
    sudo journalctl -u discord-bot -f
    # Ctrl+C で終了
  
  【トラブルシューティング】
  ────────────────────────────────────────────────────────────
  ▸ サービスが起動しない:
    sudo journalctl -u discord-bot --no-pager | tail -50
  
  ▸ トークンが無効:
    Discord Developer Portalでトークンを再生成
  
  ▸ 権限エラー:
    sudo chmod 600 /opt/discord-bot/.env
    sudo chown root:root /opt/discord-bot/.env
  
  【参考情報】
  ────────────────────────────────────────────────────────────
  インスタンスID: ${aws_instance.discord_bot.id}
  パブリックIP: ${aws_instance.discord_bot.public_ip}
  リージョン: ${var.aws_region}
  S3バケット: ${aws_s3_bucket.bot_assets.id}
  Secrets Manager: ${aws_secretsmanager_secret.discord_bot_token.name}
  
  ┌─────────────────────────────────────────────────────────────────┐
  │ セットアップ完了後、Discordサーバーでボットをメンションして    │
  │ 動作確認してください！                                          │
  └─────────────────────────────────────────────────────────────────┘
  EOT
}

# ----------------------------------------------------------------------------
# S3 Bucket Information
# ----------------------------------------------------------------------------
# アプリケーションファイルを保存するS3バケットの情報
#
# 用途:
# - 手動でのファイルアップロード時のバケット名確認
# - CI/CDパイプラインでのデプロイ先指定
# - ファイルの直接確認やダウンロード
#
# アクセス方法:
# aws s3 ls s3://<bucket_name>/
# aws s3 cp local-file.py s3://<bucket_name>/scripts/
output "s3_bucket_name" {
  description = "Discord Bot アプリケーションファイルを保存する S3 バケット名"
  value       = aws_s3_bucket.bot_assets.id
}

output "s3_bucket_arn" {
  description = "S3 バケットの ARN（IAM ポリシーで使用）"
  value       = aws_s3_bucket.bot_assets.arn
}

# ----------------------------------------------------------------------------
# Secrets Manager Information
# ----------------------------------------------------------------------------
# Discord Bot Token を保存する Secrets Manager の情報
#
# 用途:
# - トークンの更新時にシークレット名を確認
# - アクセス権限の設定
# - トークンの取得（AWS CLI）
#
# トークンの取得方法:
# aws secretsmanager get-secret-value --secret-id <secret_name> --query SecretString --output text
#
# トークンの更新方法:
# aws secretsmanager put-secret-value --secret-id <secret_name> --secret-string '{"DISCORD_BOT_TOKEN":"new-token"}'
output "secrets_manager_secret_name" {
  description = "Discord Bot Token を保存する Secrets Manager のシークレット名"
  value       = aws_secretsmanager_secret.discord_bot_token.name
}

output "secrets_manager_secret_arn" {
  description = "Secrets Manager シークレットの ARN"
  value       = aws_secretsmanager_secret.discord_bot_token.arn
  sensitive   = false
}

# ----------------------------------------------------------------------------
# Application File Paths in S3
# ----------------------------------------------------------------------------
# S3バケット内のファイルパス情報
#
# 用途:
# - ファイルの場所を確認
# - CI/CDでのデプロイ先指定
# - ドキュメントへの記載
output "s3_echo_script_key" {
  description = "S3バケット内の echo.py のキー（パス）"
  value       = aws_s3_object.echo_py.key
}

# ----------------------------------------------------------------------------
# Deployment Summary
# ----------------------------------------------------------------------------
# デプロイの概要を表示
output "deployment_summary" {
  description = "デプロイメントの概要情報"
  value = {
    environment           = var.environment
    region                = var.aws_region
    instance_id           = aws_instance.discord_bot.id
    public_ip             = aws_instance.discord_bot.public_ip
    s3_bucket             = aws_s3_bucket.bot_assets.id
    secrets_manager       = aws_secretsmanager_secret.discord_bot_token.name
    iam_role              = aws_iam_role.ec2_role.name
    security_group        = aws_security_group.discord_chatbot.name
    ssh_key_name          = aws_key_pair.discord_bot.key_name
  }
}
