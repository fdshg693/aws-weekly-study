#===============================================================================
# SQS モジュール - 変数定義
#===============================================================================

#-------------------------------------------------------------------------------
# 必須変数
#-------------------------------------------------------------------------------

variable "environment" {
  description = <<-EOT
    デプロイ環境を指定します。
    例: dev, staging, prod
    
    この値はリソース名のサフィックスとして使用され、
    環境ごとにリソースを分離するために重要です。
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は 'dev', 'staging', 'prod' のいずれかである必要があります。"
  }
}

variable "project_name" {
  description = <<-EOT
    プロジェクト名を指定します。
    
    この値はリソース名のプレフィックスとして使用されます。
    例: myapp, order-system, data-pipeline
    
    命名規則:
    - 小文字の英数字とハイフンのみ
    - 3文字以上20文字以下
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name は小文字の英数字とハイフンのみ、3〜20文字で指定してください。"
  }
}

#-------------------------------------------------------------------------------
# オプション変数 - キュー設定
#-------------------------------------------------------------------------------

variable "message_retention_seconds" {
  description = <<-EOT
    メッセージ保持期間（秒）
    
    キューにメッセージが保持される最大時間です。
    この期間を過ぎると、メッセージは自動的に削除されます。
    
    範囲: 60秒（1分）〜 1,209,600秒（14日間）
    デフォルト: 345,600秒（4日間）
    
    設定のポイント:
    - 処理遅延を考慮して余裕を持った値を設定
    - DLQ は問題調査のため長め（14日）に設定することが多い
    - 不要なメッセージの蓄積を防ぐため、適切な期間を設定
  EOT
  type        = number
  default     = 345600 # 4日間

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds は 60（1分）から 1209600（14日）の間で指定してください。"
  }
}

variable "visibility_timeout_seconds" {
  description = <<-EOT
    可視性タイムアウト（秒）
    
    メッセージが受信された後、他のコンシューマーから見えなくなる時間です。
    この時間内にメッセージを処理・削除する必要があります。
    
    範囲: 0秒 〜 43,200秒（12時間）
    デフォルト: 30秒
    
    設定のポイント:
    - Lambda のタイムアウトの6倍が AWS 推奨
    - 例: Lambda 30秒 → 可視性タイムアウト 180秒
    - 短すぎると重複処理の原因に
    - 長すぎると失敗時の再試行が遅くなる
    
    Lambda との連携時:
    - Lambda のタイムアウト設定と合わせて調整
    - バッチ処理の場合は、全メッセージの処理時間を考慮
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds は 0 から 43200（12時間）の間で指定してください。"
  }
}

variable "max_receive_count" {
  description = <<-EOT
    最大受信回数（リドライブポリシー用）
    
    メッセージがこの回数受信されると、Dead Letter Queue に移動します。
    「受信」はメッセージの取得を意味し、処理の成功/失敗ではありません。
    可視性タイムアウト内に削除されないと、受信回数がカウントアップします。
    
    範囲: 1 〜 1000
    デフォルト: 3
    
    設定のポイント:
    - 1: 1回の失敗で即 DLQ へ（厳格な処理が必要な場合）
    - 3-5: 一般的な設定（一時的な障害に対応）
    - 10以上: リトライを多く許容（ネットワーク不安定な環境など）
    
    考慮事項:
    - 一時的なエラー（タイムアウト、スロットリング）への耐性
    - 問題のあるメッセージの早期隔離
    - DLQ の監視とアラート設定
  EOT
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count は 1 から 1000 の間で指定してください。"
  }
}

#-------------------------------------------------------------------------------
# オプション変数 - タグ
#-------------------------------------------------------------------------------

variable "tags" {
  description = <<-EOT
    リソースに付与する追加タグ
    
    すべてのリソースに共通で付与したいタグを指定します。
    Name, Environment タグは自動的に付与されるため、
    それ以外のタグ（Owner, CostCenter など）を指定してください。
    
    例:
    tags = {
      Owner      = "platform-team"
      CostCenter = "12345"
      ManagedBy  = "terraform"
    }
  EOT
  type        = map(string)
  default     = {}
}
