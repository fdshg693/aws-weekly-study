#!/bin/bash

# SSH鍵ペアを生成するスクリプト
# 使用方法: ./generate_ssh_key.sh [鍵の保存先ディレクトリ] [鍵の名前]
# デフォルトは、保存先ディレクトリが ~/.ssh、鍵の名前が id_rsa
# 例: ./generate_ssh_key.sh ~/.ssh id_rsa id_rsa

set -e  # エラーが発生したら即座に終了

# カラー出力用の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# デフォルト値
DEFAULT_KEY_DIR="${HOME}/.ssh"
DEFAULT_KEY_NAME="id_rsa"

# 引数から値を取得、なければデフォルト値を使用
KEY_DIR="${1:-$DEFAULT_KEY_DIR}"
KEY_NAME="${2:-$DEFAULT_KEY_NAME}"

PRIVATE_KEY_PATH="${KEY_DIR}/${KEY_NAME}"
PUBLIC_KEY_PATH="${KEY_DIR}/${KEY_NAME}.pub"

echo -e "${GREEN}=== SSH鍵ペア生成スクリプト ===${NC}"
echo ""
echo "鍵の保存先: ${PRIVATE_KEY_PATH}"
echo ""

# ディレクトリが存在しない場合は作成
if [ ! -d "$KEY_DIR" ]; then
    echo -e "${YELLOW}ディレクトリが存在しないため作成します: ${KEY_DIR}${NC}"
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR"
fi

# 既存の鍵ファイルの確認
if [ -f "$PRIVATE_KEY_PATH" ] || [ -f "$PUBLIC_KEY_PATH" ]; then
    echo -e "${YELLOW}警告: 以下のファイルが既に存在します:${NC}"
    [ -f "$PRIVATE_KEY_PATH" ] && echo "  - ${PRIVATE_KEY_PATH}"
    [ -f "$PUBLIC_KEY_PATH" ] && echo "  - ${PUBLIC_KEY_PATH}"
    echo ""
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}処理を中止しました${NC}"
        exit 1
    fi
fi

# SSH鍵ペアの生成
echo -e "${GREEN}SSH鍵ペアを生成しています...${NC}"
ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -N "" -C "terraform-ec2-key-$(date +%Y%m%d)"

# パーミッションの設定
chmod 600 "$PRIVATE_KEY_PATH"
chmod 644 "$PUBLIC_KEY_PATH"

echo ""
echo -e "${GREEN}✓ SSH鍵ペアの生成が完了しました！${NC}"
echo ""
echo "生成されたファイル:"
echo "  秘密鍵: ${PRIVATE_KEY_PATH}"
echo "  公開鍵: ${PUBLIC_KEY_PATH}"
echo ""
echo -e "${YELLOW}重要な注意事項:${NC}"
echo "1. 秘密鍵は絶対に他人と共有しないでください"
echo "2. 秘密鍵はGitにコミットしないでください"
echo "3. .gitignoreに秘密鍵のパスを追加することを推奨します"
echo ""
echo "公開鍵の内容:"
echo "----------------------------------------"
cat "$PUBLIC_KEY_PATH"
echo "----------------------------------------"
echo ""
echo -e "${GREEN}Terraformでの使用方法:${NC}"
echo "1. public_key_path変数を設定（デフォルト: ~/.ssh/id_rsa.pub）"
echo "2. key_name変数を空にするか設定しない"
echo "3. terraform applyを実行"
echo ""
echo "例:"
echo "  terraform apply -var-file=\"dev.tfvars\" -var=\"public_key_path=${PUBLIC_KEY_PATH}\""
echo ""
