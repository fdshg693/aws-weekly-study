#!/bin/bash

# プランファイル作成処理...
echo "~~plan file is created."
echo ""
echo ""
echo "----------------------------------------"

# 入力検証ループ
while true; do
  read -p "Proceed with this plan? [yes/no]: " user_input
  
  # 小文字に正規化
  user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
  
  case "$user_input" in
    yes|y)
      echo "USER_DECISION=APPROVED"
      # 続行処理...
      exit 0
      ;;
    no|n)
      echo "USER_DECISION=REJECTED"
      exit 1
      ;;
    *)
      echo "Invalid input. Please enter 'yes' or 'no'."
      ;;
  esac
done