#!/bin/bash
# Minimal bootstrap only.
# -----------------------
# This script intentionally does NOT install or configure Ollama itself. Its role is to
# make the instance comfortable for later Session Manager access and Ansible execution.

set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "[user_data] Starting minimal bootstrap for ollama-lambda-ec2"

dnf install -y \
  python3 \
  python3-pip \
  curl \
  git \
  jq \
  tar \
  unzip

if systemctl list-unit-files | grep -q '^amazon-ssm-agent'; then
  systemctl enable --now amazon-ssm-agent
fi

mkdir -p /opt/bootstrap
cat <<'EOF' >/opt/bootstrap/README.txt
This EC2 instance is intentionally bootstrapped with only baseline tools.
Run the Ansible playbook in ./ansible to install and configure Ollama.
EOF

echo "[user_data] Bootstrap complete"
