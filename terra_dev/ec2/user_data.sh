#!/bin/bash
set -e

# ログファイルの設定
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=================================="
echo "Starting user-data script"
echo "Time: $(date)"
echo "Environment: ${environment}"
echo "=================================="

# システムアップデート
echo "Updating system packages..."
dnf update -y

# Python3とpipのインストール（Amazon Linux 2023には標準でインストール済みだが念のため）
echo "Ensuring Python3 and pip are installed..."
dnf install -y python3 python3-pip

# Ansibleのインストール
echo "Installing Ansible..."
pip3 install ansible

echo "=================================="
echo "Ansible installation completed"
echo "Ansible version: $(ansible --version | head -n 1)"
echo "Time: $(date)"
echo "=================================="
