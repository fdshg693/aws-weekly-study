#===============================================================================
# Lambda モジュール - variables.tf
#===============================================================================
# Lambda 関数の設定をカスタマイズするための変数定義
# 必須変数とオプション変数（デフォルト値あり）に分かれている
#===============================================================================

#-------------------------------------------------------------------------------
# 必須変数（Required Variables）
#-------------------------------------------------------------------------------

variable "function_name" {
  description = <<-EOT
    Lambda 関数の名前。AWS アカウント内でリージョンごとに一意である必要がある。
    命名規則の例: {プロジェクト}-{環境}-{機能}-{producer|consumer}
    例: myapp-dev-order-producer
  EOT
  type        = string

  validation {
    # Lambda 関数名の制約: 1-64文字、英数字・ハイフン・アンダースコアのみ
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.function_name))
    error_message = "関数名は1-64文字で、英数字、ハイフン、アンダースコアのみ使用可能です。"
  }
}

variable "environment" {
  description = <<-EOT
    デプロイ環境（dev, staging, prod など）。
    タグ付けやリソース命名に使用される。
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev, staging, prod のいずれかを指定してください。"
  }
}

variable "source_path" {
  description = <<-EOT
    Lambda 関数のソースコードが格納されているディレクトリのパス。
    このディレクトリ内のすべてのファイルが ZIP 化されて Lambda にデプロイされる。
    
    ディレクトリ構造の例:
    src/producer/
    ├── index.py        # メインのハンドラーファイル
    ├── utils.py        # ユーティリティ関数
    └── requirements.txt # 依存ライブラリ（別途 Layer で管理推奨）
  EOT
  type        = string
}

#-------------------------------------------------------------------------------
# ランタイム設定（Runtime Configuration）
#-------------------------------------------------------------------------------

variable "handler" {
  description = <<-EOT
    Lambda 関数のエントリーポイント。
    形式: {ファイル名（拡張子なし）}.{関数名}
    
    例:
    - index.handler → index.py の handler 関数
    - main.lambda_handler → main.py の lambda_handler 関数
    
    ハンドラー関数のシグネチャ（Python）:
    def handler(event, context):
        # event: トリガーからのイベントデータ（SQS メッセージなど）
        # context: Lambda 実行コンテキスト（残り時間、メモリ制限など）
        return response
  EOT
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = <<-EOT
    Lambda 関数のランタイム環境。
    
    Python ランタイムの選択肢:
    - python3.12: 最新の LTS、推奨
    - python3.11: 安定版
    - python3.10: レガシー対応用
    
    注意: ランタイムにはサポート終了日があるため、定期的な更新が必要
  EOT
  type        = string
  default     = "python3.12"

  validation {
    condition = contains([
      "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x"
    ], var.runtime)
    error_message = "サポートされているランタイムを指定してください。"
  }
}

#-------------------------------------------------------------------------------
# リソース設定（Resource Configuration）
#-------------------------------------------------------------------------------

variable "memory_size" {
  description = <<-EOT
    Lambda 関数に割り当てるメモリ量（MB）。
    
    重要: CPU パワーはメモリに比例して割り当てられる
    - 128MB: 最小、軽量な処理向け
    - 256MB: 一般的な API 処理
    - 512MB: データ処理、画像処理
    - 1024MB+: 機械学習、重い計算処理
    
    コストはメモリ × 実行時間で計算される
    メモリを増やすと実行時間が短くなることがあり、
    結果的にコストが下がる場合もある
  EOT
  type        = number
  default     = 128

  validation {
    # メモリは 128MB から 10240MB まで、1MB 単位で指定可能
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size は 128 から 10240 の間で指定してください。"
  }
}

variable "timeout" {
  description = <<-EOT
    Lambda 関数のタイムアウト時間（秒）。
    この時間を超えると関数は強制終了される。
    
    設定のガイドライン:
    - API Gateway 連携: 最大 29 秒（API Gateway の制限）
    - SQS トリガー: 可視性タイムアウトの 6 倍以下を推奨
    - 非同期呼び出し: 最大 900 秒（15 分）
    
    注意: タイムアウトが長いとコストが増加する可能性がある
  EOT
  type        = number
  default     = 30

  validation {
    # タイムアウトは 1 秒から 900 秒まで
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout は 1 から 900 の間で指定してください。"
  }
}

variable "reserved_concurrent_executions" {
  description = <<-EOT
    予約済み同時実行数。この関数が同時に実行できる最大インスタンス数。
    
    用途:
    - 下流システムへの負荷制御（DB 接続数の制限など）
    - コスト管理（実行数の上限設定）
    - 他の関数への影響を防ぐ（アカウント全体の同時実行数は共有）
    
    設定値の意味:
    - -1: 予約なし（アカウントの未予約プールから使用）
    - 0: 関数を無効化（一切実行されない）
    - 1以上: その数まで同時実行可能
    
    SQS トリガーとの関係:
    - SQS はメッセージ数に応じて Lambda を並列起動する
    - 同時実行数 × バッチサイズ が処理能力の上限
  EOT
  type        = number
  default     = 5

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions は -1 以上を指定してください。"
  }
}

#-------------------------------------------------------------------------------
# 環境変数（Environment Variables）
#-------------------------------------------------------------------------------

variable "environment_variables" {
  description = <<-EOT
    Lambda 関数に渡す環境変数のマップ。
    
    用途:
    - 設定値の外部化（SQS キュー URL、DynamoDB テーブル名など）
    - 環境ごとの設定切り替え
    - 機能フラグ
    
    例:
    {
      SQS_QUEUE_URL = "https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue"
      LOG_LEVEL     = "INFO"
      FEATURE_FLAG  = "true"
    }
    
    注意:
    - 機密情報（API キー、パスワードなど）は Secrets Manager を使用
    - 環境変数の合計サイズは 4KB まで
    - 値は文字列のみ（数値も文字列として渡す）
  EOT
  type        = map(string)
  default     = {}
}

#-------------------------------------------------------------------------------
# ログ設定（Logging Configuration）
#-------------------------------------------------------------------------------

variable "log_retention_days" {
  description = <<-EOT
    CloudWatch Logs のログ保持期間（日数）。
    この期間を過ぎたログは自動的に削除される。
    
    推奨設定:
    - 開発環境: 7 日（コスト削減）
    - ステージング: 14 日
    - 本番環境: 30-90 日（監査要件に応じて）
    
    使用可能な値:
    1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
  EOT
  type        = number
  default     = 7

  validation {
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days は CloudWatch Logs でサポートされている値を指定してください。"
  }
}

#-------------------------------------------------------------------------------
# IAM ポリシー（IAM Policies）
#-------------------------------------------------------------------------------

variable "additional_policies" {
  description = <<-EOT
    Lambda 関数に追加で付与する IAM ポリシーの JSON リスト。
    
    用途:
    - SQS へのメッセージ送信/受信権限
    - DynamoDB へのアクセス権限
    - S3 バケットへのアクセス権限
    - その他の AWS サービスへのアクセス
    
    例（SQS 送信権限）:
    [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["sqs:SendMessage"]
            Resource = "arn:aws:sqs:ap-northeast-1:123456789012:my-queue"
          }
        ]
      })
    ]
    
    ベストプラクティス:
    - 最小権限の原則を守る
    - リソース ARN を具体的に指定する
    - ワイルドカード（*）の使用は最小限に
  EOT
  type        = list(string)
  default     = []
}

#-------------------------------------------------------------------------------
# タグ（Tags）
#-------------------------------------------------------------------------------

variable "tags" {
  description = <<-EOT
    リソースに付与する追加のタグ。
    モジュール内で自動的に付与されるタグ（Name, Environment, ManagedBy）に
    マージされる。
    
    例:
    {
      Project   = "my-project"
      Owner     = "team-name"
      CostCenter = "12345"
    }
  EOT
  type        = map(string)
  default     = {}
}
