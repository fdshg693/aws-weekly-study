#===============================================================================
# variables.tf - Terraform 変数定義ファイル
#===============================================================================
# このファイルでは、Terraform で使用する変数を定義します。
# 変数を使用することで、環境ごとに異なる値を設定したり、
# 再利用可能なモジュールを作成したりできます。
#
# 変数の優先順位（低い順）:
# 1. default 値
# 2. terraform.tfvars ファイル
# 3. *.auto.tfvars ファイル
# 4. -var-file オプションで指定したファイル
# 5. -var オプションで直接指定
# 6. 環境変数 TF_VAR_<変数名>
#===============================================================================

#-------------------------------------------------------------------------------
# 基本設定変数
#-------------------------------------------------------------------------------

variable "aws_region" {
  description = <<-EOT
    AWS リージョン
    
    リソースをデプロイする AWS リージョンを指定します。
    日本国内向けサービスの場合は ap-northeast-1（東京）が推奨です。
    
    主要なリージョン:
    - ap-northeast-1: 東京
    - ap-northeast-3: 大阪
    - us-east-1: バージニア北部
    - us-west-2: オレゴン
  EOT
  type        = string
  default     = "ap-northeast-1"

  validation {
    # 有効な AWS リージョン形式かチェック
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS リージョンの形式が正しくありません（例: ap-northeast-1）"
  }
}

variable "environment" {
  description = <<-EOT
    環境名
    
    デプロイ先の環境を指定します。
    この値はリソース名のプレフィックス/サフィックスとして使用され、
    環境ごとにリソースを区別するのに役立ちます。
    
    許可される値:
    - dev: 開発環境
    - prod: 本番環境
  EOT
  type        = string

  validation {
    # dev または prod のみ許可
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment は 'dev' または 'prod' のいずれかである必要があります"
  }
}

variable "project_name" {
  description = <<-EOT
    プロジェクト名
    
    このプロジェクトの識別名です。
    リソース名やタグに使用されます。
    命名規則: 小文字英数字とハイフンのみ使用可能
  EOT
  type        = string
  default     = "order-processor"

  validation {
    # 小文字英数字とハイフンのみ、2-32文字
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name は小文字英数字とハイフンのみで、2-32文字である必要があります"
  }
}

#-------------------------------------------------------------------------------
# Lambda 関連変数
#-------------------------------------------------------------------------------
# AWS Lambda は設定可能なパラメータが多く、
# ワークロードに応じた適切なチューニングが重要です。

variable "lambda_memory_size" {
  description = <<-EOT
    Lambda 関数のメモリサイズ（MB）
    
    Lambda に割り当てるメモリ量を指定します。
    メモリを増やすと、比例して CPU パワーも増加します。
    
    設定範囲: 128 MB ～ 10,240 MB（1MB 単位）
    
    注意点:
    - メモリを増やすとコストも増加します
    - CPU 集約型の処理では、メモリを増やすと実行時間が短縮され、
      結果的にコストが下がる場合もあります
    - 128MB は最小値で、シンプルな処理向けです
  EOT
  type        = number
  default     = 128

  validation {
    # メモリサイズは 128MB 以上 10240MB 以下
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "lambda_memory_size は 128 ～ 10240 の範囲で指定してください"
  }
}

variable "lambda_timeout" {
  description = <<-EOT
    Lambda 関数のタイムアウト（秒）
    
    Lambda 関数の最大実行時間を指定します。
    この時間を超えると、関数は強制終了されます。
    
    設定範囲: 1 秒 ～ 900 秒（15分）
    
    ベストプラクティス:
    - 通常の実行時間より余裕を持った値を設定
    - SQS トリガーの場合、可視性タイムアウトとの関係に注意
      （可視性タイムアウト >= Lambda タイムアウト が推奨）
    - 長すぎる値はコスト増加やリトライ遅延の原因になります
  EOT
  type        = number
  default     = 30

  validation {
    # タイムアウトは 1秒 以上 900秒 以下
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "lambda_timeout は 1 ～ 900 の範囲で指定してください"
  }
}

variable "lambda_reserved_concurrent_executions" {
  description = <<-EOT
    Lambda 関数の予約済み同時実行数
    
    この Lambda 関数専用に確保する同時実行数の上限です。
    他の関数とリソースを共有せず、一定の処理能力を保証します。
    
    設定値の意味:
    - -1: 予約なし（アカウントのプールから動的に割り当て）
    - 0: 関数を無効化（呼び出し不可）
    - 1以上: 指定した数の同時実行を予約
    
    注意点:
    - 予約した分はアカウント全体の同時実行数から差し引かれます
    - SQS トリガーの場合、同時実行数がバッチ処理の並列度に影響します
    - 下流サービス（DB等）の負荷制御にも使用できます
  EOT
  type        = number
  default     = 5

  validation {
    # 同時実行数は -1（無制限）または 0 以上
    condition     = var.lambda_reserved_concurrent_executions >= -1
    error_message = "lambda_reserved_concurrent_executions は -1 以上の値を指定してください"
  }
}

#-------------------------------------------------------------------------------
# SQS 関連変数
#-------------------------------------------------------------------------------
# Amazon SQS（Simple Queue Service）は、メッセージキューサービスです。
# 適切な設定により、信頼性の高い非同期処理を実現できます。

variable "sqs_message_retention_seconds" {
  description = <<-EOT
    SQS メッセージ保持期間（秒）
    
    キューにメッセージが保持される最大時間です。
    この期間を過ぎると、メッセージは自動的に削除されます。
    
    設定範囲: 60 秒（1分）～ 1,209,600 秒（14日）
    デフォルト: 345,600 秒（4日）
    
    考慮事項:
    - 短すぎると、処理前にメッセージが失われる可能性
    - 長すぎると、古いメッセージがキューに溜まる
    - DLQ の場合は、調査時間を考慮して長めに設定
  EOT
  type        = number
  default     = 345600 # 4日 = 4 * 24 * 60 * 60

  validation {
    # 保持期間は 60秒 以上 1209600秒（14日）以下
    condition     = var.sqs_message_retention_seconds >= 60 && var.sqs_message_retention_seconds <= 1209600
    error_message = "sqs_message_retention_seconds は 60 ～ 1209600（14日）の範囲で指定してください"
  }
}

variable "sqs_visibility_timeout_seconds" {
  description = <<-EOT
    SQS 可視性タイムアウト（秒）
    
    メッセージが受信された後、他のコンシューマーから
    見えなくなる時間です。この間に処理を完了する必要があります。
    
    設定範囲: 0 秒 ～ 43,200 秒（12時間）
    デフォルト: 30 秒
    
    重要なポイント:
    - Lambda タイムアウト以上の値を設定することを推奨
    - 短すぎると、処理中に同じメッセージが再配信される
    - 長すぎると、失敗時のリトライが遅れる
    
    計算式の目安:
    可視性タイムアウト = Lambda タイムアウト × 6 + バッチウィンドウ
  EOT
  type        = number
  default     = 30

  validation {
    # 可視性タイムアウトは 0秒 以上 43200秒（12時間）以下
    condition     = var.sqs_visibility_timeout_seconds >= 0 && var.sqs_visibility_timeout_seconds <= 43200
    error_message = "sqs_visibility_timeout_seconds は 0 ～ 43200（12時間）の範囲で指定してください"
  }
}

variable "sqs_max_receive_count" {
  description = <<-EOT
    DLQ への移動までの最大受信回数
    
    メッセージが何回処理に失敗したら DLQ（デッドレターキュー）に
    移動するかを指定します。
    
    設定範囲: 1 ～ 1000
    デフォルト: 3
    
    設定の考え方:
    - 1: 一度でも失敗したらすぐに DLQ へ（厳格）
    - 3-5: 一般的な設定（一時的なエラーをリトライ）
    - 大きい値: リトライを多く試みる（ネットワーク不安定な環境等）
    
    注意:
    - 値が大きいと、問題のあるメッセージが長時間キューを占有
    - 小さいと、一時的なエラーでも DLQ に移動してしまう
  EOT
  type        = number
  default     = 3

  validation {
    # 受信回数は 1 以上 1000 以下
    condition     = var.sqs_max_receive_count >= 1 && var.sqs_max_receive_count <= 1000
    error_message = "sqs_max_receive_count は 1 ～ 1000 の範囲で指定してください"
  }
}

#-------------------------------------------------------------------------------
# CloudWatch Logs 関連変数
#-------------------------------------------------------------------------------

variable "log_retention_days" {
  description = <<-EOT
    CloudWatch Logs の保持期間（日）
    
    Lambda 関数のログが保持される期間です。
    この期間を過ぎたログは自動的に削除されます。
    
    許可される値:
    1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 
    1096, 1827, 2192, 2557, 2922, 3288, 3653, または 0（無期限）
    
    デフォルト: 7日
    
    コストとの関係:
    - ログストレージには料金がかかります
    - 開発環境: 短期間（7-14日）で十分
    - 本番環境: コンプライアンス要件に応じて設定
    - 監査ログ: 長期間または無期限
  EOT
  type        = number
  default     = 7

  validation {
    # CloudWatch Logs で許可されている保持期間の値のみ受け付け
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365,
      400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days は CloudWatch Logs で許可されている値である必要があります（0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653）"
  }
}

#===============================================================================
# 変数使用例
#===============================================================================
# 
# 1. terraform.tfvars ファイルで設定:
#    ```
#    environment = "dev"
#    lambda_memory_size = 256
#    log_retention_days = 14
#    ```
#
# 2. コマンドラインで設定:
#    ```
#    terraform apply -var="environment=prod" -var="lambda_memory_size=512"
#    ```
#
# 3. 環境変数で設定:
#    ```
#    export TF_VAR_environment="dev"
#    export TF_VAR_lambda_memory_size=256
#    terraform apply
#    ```
#
# 4. var-file オプションで設定:
#    ```
#    terraform apply -var-file="dev.tfvars"
#    ```
#===============================================================================
