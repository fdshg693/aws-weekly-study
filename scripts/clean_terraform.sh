#!/bin/bash

# 指定されたフォルダの配下を再起的に探索して、terraform の生成物を削除するスクリプト
# 削除対象：
# - .terraform フォルダ
# - terraform.tfstate ファイル
# - terraform.tfstate.backup ファイル
# - .terraform.lock.hcl ファイル

set -e

# 引数チェック
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <target_directory>"
    echo "例: $0 /path/to/terraform/projects"
    exit 1
fi

TARGET_DIR="$1"

# ディレクトリの存在確認
if [ ! -d "$TARGET_DIR" ]; then
    echo "エラー: ディレクトリが存在しません: $TARGET_DIR"
    exit 1
fi

echo "=== Terraform クリーンアップを開始 ==="
echo "対象ディレクトリ: $TARGET_DIR"
echo ""

# 削除カウンター
count_terraform_dir=0
count_tfstate=0
count_tfstate_backup=0
count_lock_hcl=0

# .terraform フォルダを削除
echo "[ .terraform フォルダを検索中... ]"
while IFS= read -r -d '' dir; do
    echo "  削除: $dir"
    rm -rf "$dir"
    ((count_terraform_dir++))
done < <(find "$TARGET_DIR" -type d -name ".terraform" -print0 2>/dev/null)

# terraform.tfstate ファイルを削除
echo ""
echo "[ terraform.tfstate ファイルを検索中... ]"
while IFS= read -r -d '' file; do
    echo "  削除: $file"
    rm -f "$file"
    ((count_tfstate++))
done < <(find "$TARGET_DIR" -type f -name "terraform.tfstate" -print0 2>/dev/null)

# terraform.tfstate.backup ファイルを削除
echo ""
echo "[ terraform.tfstate.backup ファイルを検索中... ]"
while IFS= read -r -d '' file; do
    echo "  削除: $file"
    rm -f "$file"
    ((count_tfstate_backup++))
done < <(find "$TARGET_DIR" -type f -name "terraform.tfstate.backup" -print0 2>/dev/null)

# .terraform.lock.hcl ファイルを削除
echo ""
echo "[ .terraform.lock.hcl ファイルを検索中... ]"
while IFS= read -r -d '' file; do
    echo "  削除: $file"
    rm -f "$file"
    ((count_lock_hcl++))
done < <(find "$TARGET_DIR" -type f -name ".terraform.lock.hcl" -print0 2>/dev/null)

# 結果サマリー
echo ""
echo "=== クリーンアップ完了 ==="
echo "  .terraform フォルダ: ${count_terraform_dir}件"
echo "  terraform.tfstate: ${count_tfstate}件"
echo "  terraform.tfstate.backup: ${count_tfstate_backup}件"
echo "  .terraform.lock.hcl: ${count_lock_hcl}件"
echo ""

total=$((count_terraform_dir + count_tfstate + count_tfstate_backup + count_lock_hcl))
if [ $total -eq 0 ]; then
    echo "削除対象のファイル・フォルダは見つかりませんでした。"
else
    echo "合計 ${total}個のアイテムを削除しました。"
fi