# =====================================
# 基本設定に関する変数
# =====================================

variable "aws_region" {
  description = "リソースをデプロイするAWSリージョン"
  type        = string
  default     = "ap-northeast-1" # 東京リージョン

  # リージョン形式のバリデーション
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "リージョンは有効なAWS形式である必要があります（例: ap-northeast-1）"
  }
}

variable "environment" {
  description = "デプロイ環境（development, staging, production のいずれか）"
  type        = string
  default     = "development"

  # 許可された環境名のみを受け付ける
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "環境は development, staging, production のいずれかである必要があります"
  }
}

variable "project_name" {
  description = "プロジェクト名。リソース名のプレフィックスとして使用される"
  type        = string
  default     = "dynamo-lambda-api"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 64
    error_message = "プロジェクト名は1〜64文字である必要があります"
  }
}

# =====================================
# Lambda関数の設定に関する変数
# =====================================

variable "function_name" {
  description = "Lambda関数の名前。環境名が自動的にプレフィックスとして追加されます"
  type        = string
  default     = "items-api"

  validation {
    condition     = length(var.function_name) > 0 && length(var.function_name) <= 64
    error_message = "関数名は1〜64文字である必要があります"
  }
}

variable "runtime" {
  description = <<-EOT
    Lambda関数のランタイム環境
    サポートされているランタイム:
    - python3.9, python3.10, python3.11, python3.12
  EOT
  type        = string
  default     = "python3.12"

  validation {
    condition     = contains(["python3.9", "python3.10", "python3.11", "python3.12"], var.runtime)
    error_message = "サポートされていないランタイムです"
  }
}

variable "handler" {
  description = <<-EOT
    Lambda関数のハンドラー
    形式: <ファイル名>.<関数名>
    例: lambda_function.lambda_handler
  EOT
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "memory_size" {
  description = <<-EOT
    Lambda関数に割り当てるメモリサイズ（MB単位）
    - 範囲: 128MB 〜 10,240MB
    - メモリを増やすとCPUパフォーマンスも向上

    推奨値:
    - 軽量なAPI処理: 128〜256MB
    - 中程度の処理: 256〜512MB
  EOT
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "メモリサイズは128〜10240MBの範囲である必要があります"
  }
}

variable "timeout" {
  description = <<-EOT
    Lambda関数のタイムアウト時間（秒単位）
    - 範囲: 1秒 〜 900秒（15分）
    - API Gateway経由の場合、API Gatewayのタイムアウト（29秒）にも注意
  EOT
  type        = number
  default     = 10

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "タイムアウトは1〜900秒の範囲である必要があります"
  }
}

# =====================================
# DynamoDB設定に関する変数
# =====================================

variable "dynamodb_billing_mode" {
  description = <<-EOT
    DynamoDBテーブルの課金モード
    - PAY_PER_REQUEST: オンデマンド（リクエスト量に応じた課金、開発向け）
    - PROVISIONED: プロビジョンド（固定スループットを事前に確保、本番向け）
  EOT
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "課金モードは PAY_PER_REQUEST または PROVISIONED である必要があります"
  }
}

# =====================================
# API Gateway設定に関する変数
# =====================================

variable "api_stage_name" {
  description = "API Gatewayのデプロイステージ名"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.api_stage_name)
    error_message = "ステージ名は dev, staging, prod のいずれかである必要があります"
  }
}

# =====================================
# ログ設定に関する変数
# =====================================

variable "log_retention_days" {
  description = <<-EOT
    CloudWatch Logsのログ保持期間（日数）

    環境別の推奨値:
    - 開発環境: 7日
    - ステージング: 30日
    - 本番環境: 90〜365日
  EOT
  type        = number
  default     = 7

  validation {
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "無効なログ保持期間です"
  }
}

# =====================================
# タグに関する変数
# =====================================

variable "tags" {
  description = "リソースに追加するカスタムタグ"
  type        = map(string)
  default     = {}
}
