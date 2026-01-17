#!/bin/bash

# Ansible実行スクリプト
# 使用方法: ./run_playbook.sh [environment]
# 例: ./run_playbook.sh dev

set -e

# カラー出力の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# スクリプトのディレクトリに移動
cd "$(dirname "$0")"

# 環境変数の取得（デフォルトはdev）
ENVIRONMENT=${1:-dev}

echo -e "${GREEN}=================================="
echo "Ansible Playbook実行"
echo "Environment: ${ENVIRONMENT}"
echo -e "==================================${NC}\n"

# Terraformの出力から公開IPを取得
echo -e "${YELLOW}Terraformから公開IPを取得中...${NC}"
cd ..
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo -e "${RED}エラー: 公開IPが取得できませんでした${NC}"
    echo "terraform output instance_public_ip を確認してください"
    exit 1
fi

echo -e "${GREEN}公開IP: ${PUBLIC_IP}${NC}\n"

# 一時的なインベントリファイルの作成
TEMP_INVENTORY=$(mktemp)
cat > "$TEMP_INVENTORY" << EOF
[ec2]
${PUBLIC_IP} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa

[ec2:vars]
ansible_python_interpreter=/usr/bin/python3
env_name=${ENVIRONMENT}
EOF

echo -e "${YELLOW}SSH接続テスト中...${NC}"
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ec2-user@${PUBLIC_IP} echo "OK" > /dev/null 2>&1; then
    echo -e "${RED}警告: SSH接続に失敗しました${NC}"
    echo "以下を確認してください:"
    echo "  1. セキュリティグループでSSH（ポート22）が許可されているか"
    echo "  2. SSH秘密鍵のパスが正しいか (~/.ssh/id_rsa)"
    echo "  3. インスタンスが起動完了しているか"
    echo ""
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$TEMP_INVENTORY"
        exit 1
    fi
fi

# Ansibleプレイブックの実行
echo -e "\n${GREEN}Ansibleプレイブックを実行中...${NC}\n"
cd ansible

ansible-playbook \
    -i "$TEMP_INVENTORY" \
    playbook.yml \
    -e "env_name=${ENVIRONMENT}"

# 一時ファイルの削除
rm -f "$TEMP_INVENTORY"

echo -e "\n${GREEN}=================================="
echo "完了"
echo -e "==================================${NC}"
echo -e "Webサーバーにアクセス: ${GREEN}http://${PUBLIC_IP}${NC}"
