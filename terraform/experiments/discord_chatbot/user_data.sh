#!/bin/bash

################################################################################
# Discord Bot セットアップスクリプト (Amazon Linux 2023)
################################################################################
# 
# このスクリプトは、EC2インスタンスの初回起動時に自動実行されます。
# Discord Botアプリケーションを実行するための環境をセットアップします。
#
# 実行内容:
# 1. システムパッケージのアップデート
# 2. Python3とpipのインストール確認
# 3. 必要なPythonパッケージのインストール
# 4. アプリケーションディレクトリの作成
# 5. S3からBotスクリプトをダウンロード（改善点！）
# 6. Secrets ManagerからDiscord Bot Tokenを取得（改善点！）
# 7. 環境変数ファイルの作成
# 8. systemdサービスの設定
# 9. CloudWatch Logsエージェントのセットアップ
#
# 改善点:
# - echo.pyをS3バケットからダウンロード（ベタ書き廃止）
# - Discord Bot TokenをSecrets Managerから取得（手動設定不要）
# - より安全でスケーラブルな構成
#
################################################################################

# エラー発生時にスクリプトを停止
set -e

# ログファイルの設定
# 全ての出力を/var/log/user-data.logに記録します
LOGFILE="/var/log/user-data.log"
exec > >(tee -a ${LOGFILE}) 2>&1

echo "=========================================="
echo "Discord Bot セットアップ開始"
echo "開始時刻: $(date)"
echo "=========================================="

################################################################################
# 環境変数の設定
################################################################################
# Terraformから渡される変数をシェル変数として定義
# これらの値はTerraform側で user_data の templatefile() 関数を使用して注入されます
AWS_REGION="${aws_region}"
S3_BUCKET="${s3_bucket}"
S3_SCRIPT_KEY="${s3_script_key}"
SECRETS_MANAGER_SECRET_NAME="${secrets_manager_secret_name}"
APP_DIR="/opt/discord-bot"

echo "設定情報:"
echo "  AWS Region: $AWS_REGION"
echo "  S3 Bucket: $S3_BUCKET"
echo "  S3 Script Key: $S3_SCRIPT_KEY"
echo "  Secrets Manager Secret: $SECRETS_MANAGER_SECRET_NAME"
echo "  App Directory: $APP_DIR"

################################################################################
# 1. システムアップデート
################################################################################
echo ""
echo "[1/10] システムパッケージをアップデートしています..."
# dnfはAmazon Linux 2023のパッケージマネージャーです
# -y オプションで確認なしで実行
dnf update -y

################################################################################
# 2. Python3とpipのインストール確認
################################################################################
echo ""
echo "[2/10] Python3とpipをインストールしています..."
# Amazon Linux 2023にはPython3が標準で含まれていますが、念のため確認してインストール
dnf install -y python3 python3-pip

# インストールされたバージョンを確認
echo "Python バージョン: $(python3 --version)"
echo "pip バージョン: $(pip3 --version)"

################################################################################
# 3. AWS CLIのインストール確認
################################################################################
echo ""
echo "[3/10] AWS CLIをインストールしています..."
# AWS CLI v2 は Amazon Linux 2023 に標準で含まれています
# 念のため最新版に更新
dnf install -y aws-cli

# AWS CLIのバージョン確認
echo "AWS CLI バージョン: $(aws --version)"

################################################################################
# 4. jq（JSONパーサー）のインストール
################################################################################
echo ""
echo "[4/10] jq（JSONパーサー）をインストールしています..."
# jqはJSONを解析するコマンドラインツール
# Secrets ManagerのJSON形式の出力を解析するために使用
dnf install -y jq

################################################################################
# 5. 必要なPythonパッケージのインストール
################################################################################
echo ""
echo "[5/10] Discord.pyとpython-dotenvをインストールしています..."
# discord.py: Discord APIのPythonラッパーライブラリ
# python-dotenv: .envファイルから環境変数を読み込むライブラリ
pip3 install discord.py python-dotenv

################################################################################
# 6. アプリケーションディレクトリの作成
################################################################################
echo ""
echo "[6/10] アプリケーションディレクトリを作成しています..."
# /opt は追加アプリケーションソフトウェアパッケージの標準ディレクトリ
mkdir -p $${APP_DIR}

# 作成したディレクトリに移動
cd $${APP_DIR}

################################################################################
# 7. S3からBotスクリプトをダウンロード
################################################################################
echo ""
echo "[7/10] S3からBotスクリプト（echo.py）をダウンロードしています..."
# S3バケットからecho.pyをダウンロード
# IAMロールの権限により、認証情報は不要
# エラーハンドリング: ダウンロード失敗時はスクリプトを停止

if aws s3 cp "s3://$${S3_BUCKET}/$${S3_SCRIPT_KEY}" "$${APP_DIR}/echo.py" --region "$${AWS_REGION}"; then
    echo "✓ echo.py のダウンロードに成功しました"
    chmod +x $${APP_DIR}/echo.py
else
    echo "✗ エラー: echo.py のダウンロードに失敗しました"
    echo "  S3バケット: $${S3_BUCKET}"
    echo "  スクリプトキー: $${S3_SCRIPT_KEY}"
    echo "  IAMロールの権限を確認してください"
    exit 1
fi

# オプション: requirements.txt が存在する場合はダウンロード
echo "requirements.txt の確認..."
if aws s3 ls "s3://$${S3_BUCKET}/scripts/requirements.txt" --region "$${AWS_REGION}" > /dev/null 2>&1; then
    echo "requirements.txt が見つかりました。ダウンロードしています..."
    aws s3 cp "s3://$${S3_BUCKET}/scripts/requirements.txt" "$${APP_DIR}/requirements.txt" --region "$${AWS_REGION}"
    echo "requirements.txt から追加パッケージをインストールしています..."
    pip3 install -r $${APP_DIR}/requirements.txt
else
    echo "requirements.txt は見つかりませんでした（スキップ）"
fi

################################################################################
# 8. Secrets ManagerからDiscord Bot Tokenを取得
################################################################################
echo ""
echo "[8/10] Secrets ManagerからDiscord Bot Tokenを取得しています..."
# AWS Secrets Managerからトークンを取得
# IAMロールの権限により、認証情報は不要
# jqを使用してJSON出力からDISCORD_BOT_TOKENフィールドを抽出

if SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$${SECRETS_MANAGER_SECRET_NAME}" \
    --region "$${AWS_REGION}" \
    --query SecretString \
    --output text 2>&1); then
    
    # JSONからDISCORD_BOT_TOKENフィールドを抽出
    DISCORD_BOT_TOKEN=$(echo "$SECRET_JSON" | jq -r '.DISCORD_BOT_TOKEN')
    
    if [ -z "$DISCORD_BOT_TOKEN" ] || [ "$DISCORD_BOT_TOKEN" == "null" ]; then
        echo "✗ エラー: トークンの取得に失敗しました（値が空またはnull）"
        exit 1
    fi
    
    echo "✓ Discord Bot Token の取得に成功しました"
else
    echo "✗ エラー: Secrets Managerからのトークン取得に失敗しました"
    echo "  シークレット名: $${SECRETS_MANAGER_SECRET_NAME}"
    echo "  エラー詳細: $SECRET_JSON"
    echo "  IAMロールの権限とシークレット名を確認してください"
    exit 1
fi

################################################################################
# 9. 環境変数ファイル（.env）の作成
################################################################################
echo ""
echo "[9/10] 環境変数ファイル（.env）を作成しています..."
# 取得したトークンを使用して.envファイルを作成
# Secrets Managerから取得したトークンを直接書き込むため、手動設定は不要

cat > $${APP_DIR}/.env << EOF
# Discord Bot Token
# このファイルは自動生成されました
# トークンは AWS Secrets Manager から取得されています
# 生成日時: $(date)

DISCORD_BOT_TOKEN=$${DISCORD_BOT_TOKEN}
EOF

# .envファイルのパーミッションを600に設定（所有者のみ読み書き可能）
# これはセキュリティのベストプラクティスです
chmod 600 $${APP_DIR}/.env
chown root:root $${APP_DIR}/.env

echo "✓ .env ファイルの作成が完了しました"
echo "  パーミッション: $(ls -l $${APP_DIR}/.env | awk '{print $1, $3, $4}')"

# セキュリティ: トークンをメモリから削除
unset DISCORD_BOT_TOKEN
unset SECRET_JSON

################################################################################
# 10. systemdサービスファイルの作成と起動
################################################################################
echo ""
echo "[10/10] systemdサービスファイルを作成し、サービスを起動しています..."
# systemdはLinuxのサービス管理システムです
# これにより、Botを自動起動・再起動・停止できるようになります
cat > /etc/systemd/system/discord-bot.service << SERVICEEOF
[Unit]
# サービスの説明
Description=Discord Echo Bot Service
# ネットワークが利用可能になった後に起動
After=network.target

[Service]
# サービスのタイプ: simple（メインプロセスとして起動）
Type=simple
# 実行ユーザー（セキュリティのため、rootではなく専用ユーザーが推奨）
User=root
# 作業ディレクトリ（.envファイルの相対パス解決のため重要）
WorkingDirectory=$${APP_DIR}
# 実行するコマンド
ExecStart=/usr/bin/python3 $${APP_DIR}/echo.py
# サービスが停止した場合、常に再起動
Restart=always
# 再起動までの待機時間（秒）
RestartSec=10
# 標準出力をジャーナルに記録
StandardOutput=journal
# 標準エラー出力をジャーナルに記録
StandardError=journal

[Install]
# マルチユーザーモードで有効化（通常のシステム起動時に自動起動）
WantedBy=multi-user.target
SERVICEEOF

# systemdデーモンをリロードして、新しいサービスファイルを認識させる
systemctl daemon-reload

# サービスを有効化（システム起動時に自動起動）
systemctl enable discord-bot.service

# サービスを起動
# トークンが正しく設定されているため、即座に起動します
systemctl start discord-bot.service

# 起動を少し待つ
sleep 3

# サービスの状態を確認
echo ""
echo "=========================================="
echo "サービスステータス:"
echo "=========================================="
systemctl status discord-bot.service --no-pager || true

################################################################################
# CloudWatch Logsエージェントのセットアップ
################################################################################
echo ""
echo "CloudWatch Logsエージェントをセットアップしています..."
# CloudWatch Logsエージェントを使用すると、ログをAWS CloudWatchに送信できます
# これにより、AWSコンソールからログを確認・監視できます

# CloudWatch Logsエージェントのインストール
dnf install -y amazon-cloudwatch-agent

# エージェント設定ファイルの作成
# この設定により、以下のログがCloudWatchに送信されます:
# - user-dataスクリプトのログ
# - Discord Botサービスのログ
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWEOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/discord-bot/user-data",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/discord-bot/messages",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          }
        ]
      },
      "journal": {
        "unit_whitelist": ["discord-bot.service"],
        "log_group_name": "/aws/ec2/discord-bot/service",
        "log_stream_name": "{instance_id}"
      }
    }
  }
}
CWEOF

# CloudWatch Logsエージェントを起動
# 注意: この機能を使用するには、EC2インスタンスに適切なIAMロールが必要です
# 必要な権限: CloudWatchAgentServerPolicy（既にiam.tfで設定済み）
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

echo "CloudWatch Logsエージェントが起動しました"
echo "ログは以下のロググループに送信されます:"
echo "  - /aws/ec2/discord-bot/user-data"
echo "  - /aws/ec2/discord-bot/messages"
echo "  - /aws/ec2/discord-bot/service"

################################################################################
# セットアップ完了
################################################################################
echo ""
echo "=========================================="
echo "Discord Bot セットアップ完了"
echo "完了時刻: $(date)"
echo "=========================================="
echo ""
echo "✓ すべてのセットアップが完了しました！"
echo ""
echo "【改善された点】"
echo "────────────────────────────────────────────────────────────"
echo "✓ echo.py を S3 バケットから自動ダウンロード"
echo "✓ Discord Bot Token を Secrets Manager から自動取得"
echo "✓ 手動設定が一切不要"
echo "✓ より安全でスケーラブルな構成"
echo ""
echo "【確認方法】"
echo "────────────────────────────────────────────────────────────"
echo "  サービスの状態確認:"
echo "    sudo systemctl status discord-bot.service"
echo ""
echo "  ログをリアルタイムで表示:"
echo "    sudo journalctl -u discord-bot.service -f"
echo ""
echo "  CloudWatch Logs で確認:"
echo "    AWS Console > CloudWatch > Log groups"
echo "    - /aws/ec2/discord-bot/service"
echo ""
echo "【トラブルシューティング】"
echo "────────────────────────────────────────────────────────────"
echo "  最近のログを確認:"
echo "    sudo journalctl -u discord-bot --no-pager | tail -50"
echo ""
echo "  S3からの再ダウンロード:"
echo "    aws s3 cp s3://$${S3_BUCKET}/$${S3_SCRIPT_KEY} $${APP_DIR}/echo.py"
echo "    sudo systemctl restart discord-bot"
echo ""
echo "  Secrets Managerからトークン確認:"
echo "    aws secretsmanager get-secret-value --secret-id $${SECRETS_MANAGER_SECRET_NAME} --region $${AWS_REGION}"
echo ""
echo "【Discord Botの更新方法】"
echo "────────────────────────────────────────────────────────────"
echo "  1. ローカルで echo.py を更新"
echo "  2. Terraform apply を実行（S3に自動アップロード）"
echo "  3. EC2インスタンスで以下を実行:"
echo "     aws s3 cp s3://$${S3_BUCKET}/$${S3_SCRIPT_KEY} $${APP_DIR}/echo.py"
echo "     sudo systemctl restart discord-bot"
echo ""
echo "  または、インスタンスを再作成（user_data が再実行される）"
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ セットアップ完了！                                              │"
echo "│ Discordサーバーでボットをメンションして動作確認してください！   │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "=========================================="
