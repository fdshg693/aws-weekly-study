#===============================================================================
# DynamoDB モジュール - 入力変数定義
#===============================================================================
#
# Terraform の変数は以下の優先順位で値が決定されます（上が優先）:
# 1. コマンドライン引数 (-var="key=value")
# 2. *.auto.tfvars ファイル
# 3. terraform.tfvars ファイル
# 4. 環境変数 (TF_VAR_key)
# 5. default 値
# 6. インタラクティブ入力（default がない場合）
#
#===============================================================================

#-------------------------------------------------------------------------------
# 必須変数
#-------------------------------------------------------------------------------

variable "environment" {
  description = <<-EOT
    デプロイ環境を指定します。
    
    用途:
    - リソース名のサフィックス（例: myapp-orders-dev）
    - 環境別の設定分岐
    - タグ付けによるコスト分析
    
    推奨値: dev, stg, prod
  EOT
  type        = string

  # 入力値のバリデーション
  # 想定外の値が入力された場合、terraform plan/apply 時にエラー
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment は 'dev', 'stg', 'prod' のいずれかを指定してください。"
  }
}

variable "project_name" {
  description = <<-EOT
    プロジェクト名を指定します。
    
    用途:
    - リソース名のプレフィックス（例: myapp-orders-dev）
    - 複数プロジェクトの識別
    - タグ付けによるリソース管理
    
    命名規則:
    - 小文字英数字とハイフンのみ使用推奨
    - AWS リソース名の制限に注意
      - DynamoDB テーブル名: 3-255文字、英数字、ハイフン、アンダースコア、ピリオド
  EOT
  type        = string

  validation {
    # 正規表現でプロジェクト名の形式をチェック
    # ^[a-z]: 小文字で開始
    # [a-z0-9-]*: 小文字、数字、ハイフンの繰り返し
    # [a-z0-9]$: 小文字または数字で終了
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "project_name は小文字で始まり、小文字・数字・ハイフンのみを含み、小文字または数字で終わる必要があります。"
  }

  validation {
    condition     = length(var.project_name) >= 2 && length(var.project_name) <= 50
    error_message = "project_name は 2〜50 文字で指定してください。"
  }
}

#-------------------------------------------------------------------------------
# オプション変数
#-------------------------------------------------------------------------------

variable "tags" {
  description = <<-EOT
    リソースに追加するタグのマップ。
    
    デフォルトタグ（Name, Environment, ManagedBy, Purpose）に
    マージされます。同じキーがある場合、この変数の値が優先されます。
    
    用途:
    - コスト配分タグ（CostCenter, Project）
    - 運用タグ（Owner, Team）
    - セキュリティタグ（DataClassification）
    
    使用例:
    tags = {
      CostCenter = "CC-12345"
      Owner      = "platform-team"
      Team       = "backend"
    }
  EOT
  type        = map(string)
  default     = {}

  # タグキーのバリデーション例（AWS の制限に基づく）
  # AWS タグの制限:
  # - キー: 最大128文字、値: 最大256文字
  # - aws: プレフィックスは予約済み
  validation {
    condition = alltrue([
      for key in keys(var.tags) : !startswith(key, "aws:")
    ])
    error_message = "タグキーに 'aws:' プレフィックスは使用できません（AWS 予約済み）。"
  }
}

#===============================================================================
# 追加の変数例（拡張時に使用）
#===============================================================================
#
# ■ PROVISIONED モード用の変数
#
# variable "billing_mode" {
#   description = "課金モード（PAY_PER_REQUEST または PROVISIONED）"
#   type        = string
#   default     = "PAY_PER_REQUEST"
#   
#   validation {
#     condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
#     error_message = "billing_mode は 'PAY_PER_REQUEST' または 'PROVISIONED' を指定してください。"
#   }
# }
#
# variable "read_capacity" {
#   description = "読み取りキャパシティユニット（PROVISIONED モード時のみ有効）"
#   type        = number
#   default     = 5
#   
#   validation {
#     condition     = var.read_capacity >= 1 && var.read_capacity <= 40000
#     error_message = "read_capacity は 1〜40000 の範囲で指定してください。"
#   }
# }
#
# variable "write_capacity" {
#   description = "書き込みキャパシティユニット（PROVISIONED モード時のみ有効）"
#   type        = number
#   default     = 5
# }
#
# ■ セキュリティ設定用の変数
#
# variable "enable_point_in_time_recovery" {
#   description = "Point-in-Time Recovery を有効化するか"
#   type        = bool
#   default     = false
# }
#
# variable "kms_key_arn" {
#   description = "カスタマー管理 KMS キーの ARN（null の場合は AWS 管理キー）"
#   type        = string
#   default     = null
# }
#
# ■ ストリーム設定用の変数
#
# variable "enable_stream" {
#   description = "DynamoDB Streams を有効化するか"
#   type        = bool
#   default     = true
# }
#
# variable "stream_view_type" {
#   description = "ストリームに含める情報（KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES）"
#   type        = string
#   default     = "NEW_AND_OLD_IMAGES"
# }
#
# ■ TTL 設定用の変数
#
# variable "enable_ttl" {
#   description = "TTL を有効化するか"
#   type        = bool
#   default     = true
# }
#
# variable "ttl_attribute_name" {
#   description = "TTL 判定に使用する属性名"
#   type        = string
#   default     = "expires_at"
# }
#
#===============================================================================
