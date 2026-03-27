# =====================================
# 基本設定に関する変数
# =====================================

variable "aws_region" {
  description = "Lambda関数をデプロイするAWSリージョン"
  type        = string
  default     = "ap-northeast-1" # 東京リージョン
  
  # リージョン形式のバリデーション
  # 正しいAWSリージョンフォーマットであることを確認
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

# =====================================
# Lambda関数の設定に関する変数
# =====================================

variable "function_name" {
  description = "Lambda関数の名前。環境名が自動的にプレフィックスとして追加されます"
  type        = string
  default     = "simple-lambda-function"
  
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
    - nodejs16.x, nodejs18.x, nodejs20.x
    - java11, java17, java21
    - dotnet6, dotnet8
    - ruby3.2, ruby3.3
    - provided.al2, provided.al2023 (カスタムランタイム)
  EOT
  type        = string
  default     = "python3.12"
  
  validation {
    condition = contains([
      "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs16.x", "nodejs18.x", "nodejs20.x"
    ], var.runtime)
    error_message = "サポートされていないランタイムです"
  }
}

variable "handler" {
  description = <<-EOT
    Lambda関数のハンドラー
    形式: <ファイル名>.<関数名>
    例: lambda_function.lambda_handler
    - lambda_function: Pythonファイル名（.py拡張子なし）
    - lambda_handler: 関数名
  EOT
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "memory_size" {
  description = <<-EOT
    Lambda関数に割り当てるメモリサイズ（MB単位）
    - 範囲: 128MB 〜 10,240MB（10GB）
    - 増分: 1MB単位
    - メモリを増やすとCPUパフォーマンスも向上
    - 料金: メモリサイズと実行時間に基づいて課金
    
    推奨値:
    - 軽量な処理: 128〜512MB
    - 中程度の処理: 512〜1024MB
    - 重い処理: 1024〜3008MB
    - 非常に重い処理: 3008MB以上
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
    - デフォルト: 3秒
    
    用途別の推奨値:
    - API応答: 3〜30秒
    - データ処理: 30〜300秒
    - バッチ処理: 300〜900秒
    
    注意: 長時間実行する処理はコストが増加します
  EOT
  type        = number
  default     = 3
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "タイムアウトは1〜900秒の範囲である必要があります"
  }
}

# =====================================
# Lambda関数の環境変数
# =====================================

variable "environment_variables" {
  description = <<-EOT
    Lambda関数で使用する環境変数のマップ
    - 最大4KB（すべての変数の合計）
    - 機密情報は暗号化を推奨（KMS使用）
    
    例:
    environment_variables = {
      LOG_LEVEL    = "INFO"
      DATABASE_URL = "postgresql://..."
      API_KEY      = "your-api-key"
    }
  EOT
  type        = map(string)
  default     = {}
}

# =====================================
# ログ設定に関する変数
# =====================================

variable "log_retention_days" {
  description = <<-EOT
    CloudWatch Logsのログ保持期間（日数）
    
    利用可能な値:
    1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    
    0を指定すると無期限に保持（推奨しない）
    
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
# VPC設定に関する変数（オプション）
# =====================================

variable "enable_vpc" {
  description = <<-EOT
    Lambda関数をVPC内で実行するかどうか
    
    VPC内で実行する場合:
    - プライベートリソース（RDS、ElastiCache等）にアクセス可能
    - インターネットアクセスにはNAT Gatewayが必要
    - コールドスタート時間が増加
    
    VPC外で実行する場合:
    - インターネットアクセスが高速
    - AWS管理サービスへのアクセスが容易
    - プライベートリソースには直接アクセス不可
  EOT
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "Lambda関数を配置するVPCサブネットのIDリスト（enable_vpc = true の場合に必須）"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Lambda関数に適用するセキュリティグループのIDリスト（enable_vpc = true の場合に必須）"
  type        = list(string)
  default     = []
}

# =====================================
# 予約された同時実行数の設定
# =====================================

variable "reserved_concurrent_executions" {
  description = <<-EOT
    Lambda関数の予約済み同時実行数
    
    - -1: 制限なし（デフォルト）
    - 0: 関数を無効化
    - 1以上: 指定された数までの同時実行を予約
    
    用途:
    - 重要な関数のために実行数を確保
    - 暴走を防ぐための上限設定
    - コスト管理
    
    注意: アカウント全体の同時実行数の上限は1000（デフォルト）
  EOT
  type        = number
  default     = -1
  
  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "同時実行数は-1以上である必要があります"
  }
}

# =====================================
# デッドレターキュー（DLQ）の設定
# =====================================

variable "enable_dlq" {
  description = <<-EOT
    デッドレターキュー（DLQ）を有効にするかどうか
    
    DLQの役割:
    - 失敗したイベントを別のSQSキューまたはSNSトピックに送信
    - 失敗したイベントの調査・再処理が可能
    - 非同期実行の信頼性向上
    
    使用場面:
    - イベント駆動のアーキテクチャ
    - データ損失を防ぐ必要がある場合
    - エラーハンドリングの追跡
  EOT
  type        = bool
  default     = false
}

variable "dlq_target_arn" {
  description = "DLQのターゲットARN（SQSキューまたはSNSトピック）"
  type        = string
  default     = ""
}

# =====================================
# タグに関する変数
# =====================================

variable "tags" {
  description = <<-EOT
    Lambda関数に追加するカスタムタグ
    
    タグの活用例:
    - コスト配分追跡
    - リソース管理
    - アクセス制御
    - 自動化のトリガー
  EOT
  type        = map(string)
  default     = {}
}

# =====================================
# トレーシングの設定
# =====================================

variable "tracing_mode" {
  description = <<-EOT
    AWS X-Rayトレーシングモード
    
    - PassThrough: X-Rayトレーシングヘッダーを伝播するが、セグメントは作成しない
    - Active: X-Rayセグメントを作成し、詳細なトレース情報を収集
    
    X-Rayの利点:
    - パフォーマンスの可視化
    - ボトルネックの特定
    - エラーの追跡
    - サービス間の依存関係の理解
  EOT
  type        = string
  default     = "PassThrough"
  
  validation {
    condition     = contains(["PassThrough", "Active"], var.tracing_mode)
    error_message = "トレーシングモードは PassThrough または Active である必要があります"
  }
}
