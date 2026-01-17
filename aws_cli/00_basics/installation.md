# AWS CLI インストールガイド

AWS CLI (Command Line Interface) のインストール方法を各プラットフォーム別に詳しく解説します。

## 目次
- [インストール方法の概要](#インストール方法の概要)
- [macOS へのインストール](#macos-へのインストール)
- [Linux へのインストール](#linux-へのインストール)
- [Windows へのインストール](#windows-へのインストール)
- [Docker でのインストール](#docker-でのインストール)
- [バージョン確認](#バージョン確認)
- [アップグレード](#アップグレード)
- [アンインストール](#アンインストール)

---

## インストール方法の概要

AWS CLI には主に2つのバージョンがあります：
- **AWS CLI v2** - 最新版（推奨）
- **AWS CLI v1** - レガシー版

このドキュメントでは、主に AWS CLI v2 のインストール方法を説明します。

---

## macOS へのインストール

### 方法1: 公式インストーラー（推奨）

最も簡単で確実な方法です。

```bash
# Intel Mac の場合
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Apple Silicon (M1/M2/M3) の場合は自動検出されます
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**特徴:**
- システム全体にインストール
- `/usr/local/bin/aws` にコマンドが配置される
- 管理者権限が必要

### 方法2: Homebrew

開発者に人気のパッケージマネージャーを使用します。

```bash
# Homebrew がインストールされていない場合
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# AWS CLI v2 のインストール
brew install awscli

# 特定のバージョンをインストール
brew install awscli@2
```

**特徴:**
- Homebrew で他のパッケージと一元管理
- アップデートが簡単（`brew upgrade awscli`）
- `/opt/homebrew/bin/aws` または `/usr/local/bin/aws` に配置

**Tips:**
```bash
# Homebrew でインストールした場合のパス確認
which aws
# /opt/homebrew/bin/aws

# バージョン確認
aws --version
# aws-cli/2.15.0 Python/3.11.6 Darwin/23.1.0 source/arm64
```

### 方法3: pip（Python パッケージマネージャー）

Python 環境がある場合に使用できます。

```bash
# AWS CLI v2 は pip でインストール不可（v1のみ）
# v1 のインストール（非推奨）
pip3 install awscli

# 仮想環境での使用を推奨
python3 -m venv aws-cli-env
source aws-cli-env/bin/activate
pip install awscli
```

**注意:** AWS CLI v2 は pip でインストールできません。v2 を使いたい場合は公式インストーラーか Homebrew を使用してください。

---

## Linux へのインストール

### 方法1: 公式インストーラー（推奨）

すべての Linux ディストリビューションで使用可能です。

```bash
# x86_64 アーキテクチャ
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# ARM アーキテクチャ（例: Raspberry Pi）
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**カスタムインストールパス:**
```bash
# システムディレクトリへの書き込み権限がない場合
./aws/install -i ~/aws-cli -b ~/bin

# パスの説明:
# -i : インストールディレクトリ
# -b : シンボリックリンクを作成するディレクトリ
```

**パスの追加:**
```bash
# ~/.bashrc または ~/.zshrc に追加
export PATH=$HOME/bin:$PATH

# 設定を反映
source ~/.bashrc
```

### 方法2: apt（Ubuntu/Debian）

```bash
# システムを最新化
sudo apt update
sudo apt upgrade -y

# 依存パッケージのインストール
sudo apt install -y unzip curl

# 公式インストーラーを使用（上記の方法1と同じ）
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# または AWS CLI v1（レガシー）
sudo apt install -y awscli
```

**Ubuntu での完全な例:**
```bash
#!/bin/bash
# Ubuntu に AWS CLI v2 をインストールするスクリプト

# 既存のバージョンを確認
if command -v aws &> /dev/null; then
    echo "現在のバージョン: $(aws --version)"
    read -p "既存の AWS CLI を削除してインストールしますか？ (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf /usr/local/aws-cli
        sudo rm /usr/local/bin/aws
        sudo rm /usr/local/bin/aws_completer
    fi
fi

# 依存パッケージ
sudo apt update
sudo apt install -y unzip curl

# ダウンロードとインストール
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
```

### 方法3: yum（Amazon Linux/CentOS/RHEL）

```bash
# Amazon Linux 2 の場合
sudo yum update -y
sudo yum install -y unzip curl

# 公式インストーラーを使用
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# または yum で v1 をインストール（レガシー）
sudo yum install -y aws-cli
```

**Amazon Linux 2023 の場合:**
```bash
# デフォルトで AWS CLI v2 が含まれています
aws --version

# 最新版にアップデート
sudo yum update -y aws-cli
```

### 方法4: snap（Ubuntu）

```bash
# snap を使用したインストール
sudo snap install aws-cli --classic

# バージョン確認
aws --version
```

---

## Windows へのインストール

### 方法1: MSI インストーラー（推奨）

最も簡単な方法です。

**64-bit Windows の場合:**
1. [AWS CLI MSI インストーラー](https://awscli.amazonaws.com/AWSCLIV2.msi) をダウンロード
2. ダウンロードしたファイルをダブルクリック
3. インストールウィザードに従う

**コマンドラインからのインストール:**
```powershell
# PowerShell で実行
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# サイレントインストール（管理者権限が必要）
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet
```

**インストール後の確認:**
```powershell
# コマンドプロンプトまたは PowerShell
aws --version

# パスが通っていない場合
# 環境変数 PATH に以下を追加:
# C:\Program Files\Amazon\AWSCLIV2
```

### 方法2: Chocolatey

Windows のパッケージマネージャー Chocolatey を使用します。

```powershell
# Chocolatey のインストール（管理者権限で PowerShell を実行）
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# AWS CLI のインストール
choco install awscli -y

# バージョン確認
aws --version
```

### 方法3: pip（Windows）

```powershell
# Python がインストールされている場合
pip install awscli

# 仮想環境での使用を推奨
python -m venv aws-cli-env
.\aws-cli-env\Scripts\activate
pip install awscli
```

### 方法4: Windows Subsystem for Linux (WSL)

WSL を使用している場合は、Linux の手順に従ってください。

```bash
# WSL Ubuntu での例
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

---

## Docker でのインストール

コンテナ環境で AWS CLI を使用する方法です。

### 公式 Docker イメージの使用

```bash
# 最新版の実行
docker run --rm -it amazon/aws-cli --version

# 認証情報をマウントして実行
docker run --rm -it \
  -v ~/.aws:/root/.aws \
  amazon/aws-cli s3 ls

# 作業ディレクトリもマウント
docker run --rm -it \
  -v ~/.aws:/root/.aws \
  -v $(pwd):/aws \
  amazon/aws-cli s3 cp /aws/myfile.txt s3://my-bucket/
```

### エイリアスの作成

毎回長いコマンドを入力するのは面倒なので、エイリアスを作成します。

```bash
# ~/.bashrc または ~/.zshrc に追加
alias aws='docker run --rm -it -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'

# 使用例
aws s3 ls
aws ec2 describe-instances
```

### カスタム Dockerfile

独自の Docker イメージに AWS CLI を含める場合：

```dockerfile
# Alpine ベース
FROM alpine:latest

RUN apk --no-cache add \
    curl \
    unzip \
    python3 \
    py3-pip \
    && pip3 install --upgrade pip \
    && pip3 install awscli \
    && rm -rf /var/cache/apk/*

CMD ["/bin/sh"]
```

```dockerfile
# Ubuntu ベース（AWS CLI v2）
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y \
    curl \
    unzip \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws \
    && apt-get clean

CMD ["/bin/bash"]
```

**ビルドと実行:**
```bash
# イメージのビルド
docker build -t my-aws-cli .

# 実行
docker run --rm -it \
  -v ~/.aws:/root/.aws \
  my-aws-cli aws --version
```

### Docker Compose での使用

```yaml
# docker-compose.yml
version: '3.8'

services:
  aws-cli:
    image: amazon/aws-cli
    volumes:
      - ~/.aws:/root/.aws:ro
      - ./data:/data
    command: s3 ls
    environment:
      - AWS_PROFILE=default
```

```bash
# 実行
docker-compose run --rm aws-cli s3 ls
docker-compose run --rm aws-cli ec2 describe-instances
```

---

## バージョン確認

インストール後は必ずバージョンを確認しましょう。

### 基本的な確認

```bash
# バージョン情報の表示
aws --version

# 出力例:
# aws-cli/2.15.0 Python/3.11.6 Darwin/23.1.0 source/arm64
```

### 詳細情報の確認

```bash
# インストールパスの確認
which aws
# /opt/homebrew/bin/aws

# シンボリックリンクの実体を確認
ls -l $(which aws)
# /opt/homebrew/bin/aws -> ../Cellar/awscli/2.15.0/bin/aws

# Python バージョンの確認
python3 --version
```

### バージョン情報の解析

```bash
aws --version

# 出力の意味:
# aws-cli/2.15.0        ← AWS CLI のバージョン
# Python/3.11.6         ← 内部で使用している Python のバージョン
# Darwin/23.1.0         ← OS カーネルのバージョン
# source/arm64          ← アーキテクチャ（arm64/x86_64）
```

---

## アップグレード

AWS CLI を最新版にアップグレードする方法です。

### macOS でのアップグレード

**公式インストーラーの場合:**
```bash
# 最新版のインストーラーをダウンロードして実行
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# 既存のバージョンに上書きされます
```

**Homebrew の場合:**
```bash
# AWS CLI のみアップグレード
brew upgrade awscli

# すべてのパッケージをアップグレード
brew upgrade

# アップグレード可能なパッケージを確認
brew outdated
```

### Linux でのアップグレード

**公式インストーラーの場合:**
```bash
# 既存のバージョンを削除してから再インストール
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update

# または既存のインストールを削除してから新規インストール
sudo rm -rf /usr/local/aws-cli
sudo rm /usr/local/bin/aws
sudo rm /usr/local/bin/aws_completer
sudo ./aws/install
```

**apt の場合:**
```bash
sudo apt update
sudo apt upgrade awscli
```

**yum の場合:**
```bash
sudo yum update aws-cli
```

### Windows でのアップグレード

**MSI インストーラーの場合:**
1. 新しい MSI インストーラーをダウンロード
2. 実行すると既存のバージョンが自動的にアップグレードされます

**Chocolatey の場合:**
```powershell
choco upgrade awscli -y
```

**pip の場合:**
```bash
pip install --upgrade awscli
```

### アップグレード確認スクリプト

```bash
#!/bin/bash
# AWS CLI のバージョンをチェックして最新版にアップグレード

CURRENT_VERSION=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
echo "現在のバージョン: $CURRENT_VERSION"

# Homebrew でインストールされているか確認
if brew list awscli &>/dev/null; then
    echo "Homebrew でインストールされています"
    brew upgrade awscli
elif [ -f "/usr/local/bin/aws" ]; then
    echo "公式インストーラーでインストールされています"
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    sudo ./aws/install --update
    rm -rf awscliv2.zip aws
else
    echo "インストール方法を特定できませんでした"
fi

# 新しいバージョンを表示
echo "新しいバージョン: $(aws --version)"
```

---

## アンインストール

AWS CLI を完全に削除する方法です。

### macOS でのアンインストール

**公式インストーラーの場合:**
```bash
# シンボリックリンクを削除
sudo rm /usr/local/bin/aws
sudo rm /usr/local/bin/aws_completer

# インストールディレクトリを削除
sudo rm -rf /usr/local/aws-cli

# 設定ファイルも削除する場合（注意: 認証情報も削除されます）
rm -rf ~/.aws
```

**Homebrew の場合:**
```bash
# AWS CLI のアンインストール
brew uninstall awscli

# 依存関係も削除
brew autoremove

# 設定ファイルの削除（必要に応じて）
rm -rf ~/.aws
```

### Linux でのアンインストール

**公式インストーラーの場合:**
```bash
# AWS CLI の削除
sudo rm /usr/local/bin/aws
sudo rm /usr/local/bin/aws_completer
sudo rm -rf /usr/local/aws-cli

# 設定ファイルの削除
rm -rf ~/.aws
```

**apt の場合:**
```bash
sudo apt remove awscli
sudo apt autoremove
rm -rf ~/.aws
```

**yum の場合:**
```bash
sudo yum remove aws-cli
rm -rf ~/.aws
```

**snap の場合:**
```bash
sudo snap remove aws-cli
rm -rf ~/.aws
```

### Windows でのアンインストール

**MSI インストーラーの場合:**
1. 「設定」→「アプリ」→「インストールされているアプリ」
2. "AWS Command Line Interface v2" を検索
3. 「アンインストール」をクリック

**コマンドラインから:**
```powershell
# プログラムの一覧から AWS CLI の製品コードを取得
wmic product where name="AWS Command Line Interface v2" call uninstall

# または
msiexec.exe /x {製品コード}
```

**Chocolatey の場合:**
```powershell
choco uninstall awscli -y
```

**pip の場合:**
```bash
pip uninstall awscli
```

**設定ファイルの削除:**
```powershell
# PowerShell
Remove-Item -Recurse -Force $env:USERPROFILE\.aws
```

### 完全削除の確認

```bash
# コマンドが存在しないことを確認
which aws
# 出力なし

aws --version
# command not found: aws

# 設定ファイルが削除されたことを確認
ls ~/.aws
# No such file or directory
```

---

## トラブルシューティング

### よくある問題と解決方法

**1. コマンドが見つからない（command not found）**
```bash
# パスの確認
echo $PATH

# AWS CLI のインストール場所を探す
find /usr -name aws 2>/dev/null
find ~ -name aws 2>/dev/null

# パスを手動で追加
export PATH=$PATH:/usr/local/bin
```

**2. バージョンの競合**
```bash
# インストールされているすべての aws コマンドを表示
which -a aws

# 出力例:
# /usr/local/bin/aws      ← v2
# /usr/bin/aws            ← v1

# 不要なバージョンを削除
sudo rm /usr/bin/aws
```

**3. 権限エラー**
```bash
# インストール時に権限エラーが出る場合
sudo chown -R $(whoami) /usr/local/bin
sudo chown -R $(whoami) /usr/local/aws-cli

# またはユーザーディレクトリにインストール
./aws/install -i ~/aws-cli -b ~/bin
```

**4. SSL 証明書エラー**
```bash
# 企業のプロキシ環境などで発生する場合
export AWS_CA_BUNDLE=/path/to/ca-bundle.crt

# または証明書検証を無効化（非推奨）
aws s3 ls --no-verify-ssl
```

---

## ベストプラクティス

### 推奨するインストール方法

1. **macOS**: Homebrew（管理が簡単）または公式インストーラー
2. **Linux**: 公式インストーラー（互換性が高い）
3. **Windows**: MSI インストーラー（最も簡単）
4. **コンテナ環境**: 公式 Docker イメージ

### バージョン管理

```bash
# 定期的にバージョンを確認
aws --version

# 月1回程度アップデートをチェック
# macOS (Homebrew)
brew outdated | grep awscli

# リリースノートを確認
# https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
```

### 複数バージョンの管理

```bash
# asdf を使用したバージョン管理
asdf plugin add awscli
asdf install awscli 2.15.0
asdf install awscli 2.14.0
asdf global awscli 2.15.0

# プロジェクトごとに異なるバージョンを使用
cd project1
asdf local awscli 2.15.0

cd project2
asdf local awscli 2.14.0
```

---

## まとめ

- AWS CLI v2 の使用を推奨
- 各 OS に適したインストール方法を選択
- 定期的なアップデートを実施
- Docker を活用した環境分離も有効
- トラブルシューティングの基本を把握

次は [configuration.md](configuration.md) で AWS CLI の設定方法を学びましょう。
