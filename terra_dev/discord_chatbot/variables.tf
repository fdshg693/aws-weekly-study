# ============================================
# 基本設定変数
# ============================================
# プロジェクト全体で使用する基本的な設定値を定義します

# AWSリージョンの指定
# ----------------------------------------
# デプロイ先のAWSリージョンを指定します
# 
# 主要なリージョンの選び方:
# - ap-northeast-1 (東京): 日本向けサービスに最適、低レイテンシ
# - ap-northeast-3 (大阪): DRサイトや冗長化に使用
# - us-east-1 (バージニア北部): グローバルサービス、一部サービスの先行リリース
# - eu-west-1 (アイルランド): ヨーロッパ向けサービス
# 
# ベストプラクティス:
# - ユーザーに近いリージョンを選択（レイテンシ低減）
# - コンプライアンス要件を考慮（データの地理的制約）
# - 利用したいサービスの提供状況を確認
variable "aws_region" {
  description = "AWSリージョン（デフォルト: 東京リージョン）"
  type        = string
  default     = "ap-northeast-1"

  # バリデーション（オプション）
  # 不正な値が入力された場合にエラーを表示
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "リージョンは 'ap-northeast-1' のような形式で指定してください。"
  }
}

# 環境名の指定
# ----------------------------------------
# 開発、ステージング、本番などの環境を区別するための変数
# 
# 一般的な環境名:
# - dev: 開発環境（開発者が日常的に使用）
# - stg/staging: ステージング環境（本番前のテスト）
# - prod/production: 本番環境（エンドユーザーが使用）
# - test: テスト専用環境（自動テストなど）
# 
# ベストプラクティス:
# - 環境ごとに別のAWSアカウントを使用することを推奨
# - タグやリソース名に環境名を含めて識別しやすくする
variable "environment" {
  description = "環境名（dev, stg, prod など）"
  type        = string
  default     = "dev"

  # バリデーション: 許可された環境名のみ受け入れる
  validation {
    condition     = contains(["dev", "stg", "staging", "prod", "production", "test"], var.environment)
    error_message = "環境名は dev, stg, staging, prod, production, test のいずれかを指定してください。"
  }
}

# プロジェクト名
# ----------------------------------------
# リソース名のプレフィックスとして使用
# 複数のプロジェクトを管理する際の識別に使用
# 
# 命名規則のベストプラクティス:
# - 小文字とハイフンのみを使用（一部のAWSリソースの制約）
# - 短く分かりやすい名前を使用
# - 組織名やチーム名を含めることも検討
variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスとして使用）"
  type        = string
  default     = "discord-bot"

  # バリデーション: 命名規則に従っているか確認
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "プロジェクト名は小文字、数字、ハイフンのみ使用できます。"
  }
}

# ============================================
# EC2インスタンス設定
# ============================================

# インスタンスタイプ
# ----------------------------------------
# EC2インスタンスのサイズを指定します
# 
# 主要なインスタンスタイプ:
# - t2.micro: 1 vCPU, 1GB RAM（無料利用枠対象）
# - t2.small: 1 vCPU, 2GB RAM
# - t2.medium: 2 vCPU, 4GB RAM
# - t3.micro: 2 vCPU, 1GB RAM（新世代、バースト性能向上）
# - t3.small: 2 vCPU, 2GB RAM
# 
# T2/T3インスタンスの特徴:
# - バースト可能なパフォーマンス（CPUクレジット制）
# - 低コストで小規模なワークロードに最適
# - 持続的な高負荷には不向き（クレジット消費）
# 
# その他の選択肢:
# - M6i/M5シリーズ: 汎用、バランス型
# - C6i/C5シリーズ: コンピューティング最適化
# - R6i/R5シリーズ: メモリ最適化
# 
# ベストプラクティス:
# - 本番環境では T3 シリーズの使用を推奨（T2より効率的）
# - 学習・開発では t2.micro（無料利用枠）
# - 負荷に応じて適切なサイズを選択
variable "instance_type" {
  description = "EC2インスタンスタイプ（t2.micro は無料利用枠対象）"
  type        = string
  default     = "t2.micro"

  # バリデーション: 一般的なインスタンスタイプのみ許可
  validation {
    condition = can(regex("^t[23]\\.(micro|small|medium|large)|^m[56]\\.(large|xlarge)|^c[56]\\.(large|xlarge)$", var.instance_type))
    error_message = "サポートされているインスタンスタイプを指定してください（例: t2.micro, t3.small など）。"
  }
}

# ============================================
# セキュリティ設定
# ============================================

# SSH接続を許可するIPアドレス
# ----------------------------------------
# SSH（ポート22）への接続を許可するIPアドレス範囲を指定
# 
# セキュリティレベル:
# 1. 特定IP: "203.0.113.1/32"（最も安全、推奨）
#    - 自分のIPアドレスのみを許可
#    - 最も安全な設定
# 
# 2. 組織のIP範囲: "203.0.113.0/24"（安全）
#    - 組織のネットワークから許可
#    - 複数拠点がある場合に便利
# 
# 3. 全世界に公開: "0.0.0.0/0"（危険、非推奨）
#    - どこからでも接続可能
#    - テスト目的のみに限定すべき
#    - 本番環境では絶対に使用しないこと
# 
# セキュリティのベストプラクティス:
# - 本番環境では特定のIPアドレスのみを許可
# - VPN経由でのアクセスを推奨
# - Session Manager（SSM）の使用を検討（SSHポート不要）
# - 定期的なセキュリティグループの見直し
variable "my_ip" {
  description = "SSH接続を許可するIPアドレス（CIDR形式）。セキュリティのため、特定のIPアドレスを指定することを推奨。"
  type        = string
  default     = "0.0.0.0/0" # デフォルトは全開放（学習用）。本番環境では必ず変更すること！

  # バリデーション: CIDR形式の確認
  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "IPアドレスはCIDR形式で指定してください（例: 203.0.113.1/32）。"
  }
}

# SSH公開鍵ファイルのパス
# ----------------------------------------
# EC2インスタンスへのSSH接続に使用する公開鍵ファイルのパス
# 
# SSH鍵ペアについて:
# - 公開鍵（.pub）: EC2に登録する鍵（共有可能）
# - 秘密鍵: ローカルに保管し、SSH接続時に使用（絶対に共有しない）
# 
# 鍵ペアの作成方法:
#   ssh-keygen -t rsa -b 4096 -f ./ssh-secrets/discord-bot-key
#   # または
#   ssh-keygen -t ed25519 -f ./ssh-secrets/discord-bot-key
# 
# 推奨される鍵の種類:
# - RSA 4096ビット: 広くサポートされている（推奨）
# - Ed25519: 新しい形式、より短く安全（最新システムで推奨）
# 
# セキュリティのベストプラクティス:
# - パスフレーズを設定して鍵を保護
# - 秘密鍵のパーミッションを 600 に設定（chmod 600）
# - 秘密鍵は .gitignore に追加（絶対にコミットしない）
# - 定期的な鍵のローテーション
# - 鍵ごとに異なる用途を分ける
variable "ssh_public_key_path" {
  description = "SSH公開鍵ファイルのパス（EC2インスタンスへのSSH接続に使用）"
  type        = string
  default     = "./ssh-secrets/discord-bot-key.pub"

  # バリデーション: ファイルパスが .pub で終わることを確認
  validation {
    condition     = can(regex("\\.pub$", var.ssh_public_key_path))
    error_message = "公開鍵ファイルのパスを指定してください（.pub で終わる必要があります）。"
  }
}

# ============================================
# アプリケーション設定
# ============================================

# Discord Bot トークン
# ----------------------------------------
# Discord Bot の認証トークン
# 
# セキュリティ上の重要な注意事項:
# - この変数に設定された値は AWS Secrets Manager に保存されます
# - tfvars ファイルに記載する場合は .gitignore に追加必須
# - Git履歴にトークンを含めない（漏洩した場合は即座にリセット）
# - terraform.tfstate にも記録されるため、tfstate の保護が重要
# 
# トークンの管理方法:
# 1. 環境変数（推奨）:
#    export TF_VAR_discord_bot_token="your-token"
# 
# 2. *.tfvars ファイル（.gitignoreに追加必須）:
#    discord_bot_token = "your-token"
# 
# 3. Terraform Cloud/Enterprise のワークスペース変数
# 
# 4. デフォルト（自動）:
#    環境変数が未設定の場合、python/.env ファイルから自動的に読み取ります
# 
# トークンの取得方法:
# 1. Discord Developer Portal にアクセス
#    https://discord.com/developers/applications
# 2. アプリケーションを選択
# 3. "Bot" タブを開く
# 4. "TOKEN" セクションで "Reset Token" または "Copy" をクリック
# 
# ベストプラクティス:
# - デプロイ後はトークンが Secrets Manager に保存されます
# - EC2 インスタンスは IAM ロールを使用して Secrets Manager から取得
# - トークンのローテーション時は Secrets Manager を更新
variable "discord_bot_token" {
  description = "Discord Botの認証トークン（AWS Secrets Managerに保存されます）。未指定の場合はpython/.envから読み取ります。"
  type        = string
  default     = ""
  sensitive   = true # この変数の値をログに出力しない
}

# S3古いバージョンの保持期間
# ----------------------------------------
# S3バケットのライフサイクルルールで使用
# 古いバージョンのファイルを指定日数後に削除します
#
# 考慮事項:
# - 短すぎると誤って削除した場合に復元できない
# - 長すぎるとストレージコストが増加
# - 開発環境では短く、本番環境では長く設定することを推奨
variable "s3_old_version_retention_days" {
  description = "S3バケットの古いバージョンを保持する日数（ライフサイクルルール）"
  type        = number
  default     = 30

  validation {
    condition     = var.s3_old_version_retention_days >= 1 && var.s3_old_version_retention_days <= 365
    error_message = "保持期間は 1 から 365 日の間で指定してください。"
  }
}

# ============================================
# 変数の使用例
# ============================================
# これらの変数は以下のように使用します:
# 
# 1. コマンドライン:
#    terraform apply -var="environment=prod" -var="instance_type=t3.small"
# 
# 2. terraform.tfvars ファイル:
#    environment   = "prod"
#    instance_type = "t3.small"
#    my_ip         = "203.0.113.1/32"
# 
# 3. 環境変数:
#    export TF_VAR_environment="prod"
#    export TF_VAR_instance_type="t3.small"
# 
# 4. 環境別の設定ファイル:
#    terraform apply -var-file="prod.tfvars"
# 
# 優先順位（高→低）:
# 1. コマンドラインの -var オプション
# 2. -var-file オプション
# 3. terraform.tfvars または *.auto.tfvars
# 4. 環境変数 TF_VAR_*
# 5. デフォルト値
