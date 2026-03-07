#===============================================================================
# API Gateway モジュール - 変数定義
#===============================================================================
# 
# このファイルでは API Gateway モジュールで使用する変数を定義します。
#
#===============================================================================

#-------------------------------------------------------------------------------
# 必須変数
#-------------------------------------------------------------------------------

variable "environment" {
  description = <<-EOT
    デプロイ環境の名前。
    ステージ名としても使用されます。
    
    例: dev, staging, prod
    
    API の URL は以下の形式になります:
    https://{api-id}.execute-api.{region}.amazonaws.com/{environment}/orders
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev, staging, prod のいずれかである必要があります。"
  }
}

variable "project_name" {
  description = <<-EOT
    プロジェクト名。
    リソース名のプレフィックスとして使用されます。
    
    命名規則: 小文字英数字とハイフンのみ
    
    作成されるリソース名の例:
    - API: {project_name}-api-{environment}
    - ログ: /aws/api-gateway/{project_name}-{environment}
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name は小文字英数字とハイフンのみ使用できます。"
  }
}

variable "lambda_function_name" {
  description = <<-EOT
    統合する Lambda 関数の名前。
    API Gateway に Lambda の実行権限を付与する際に使用します。
    
    aws_lambda_function.xxx.function_name の値を渡してください。
  EOT
  type        = string
}

variable "lambda_invoke_arn" {
  description = <<-EOT
    統合する Lambda 関数の Invoke ARN。
    API Gateway から Lambda を呼び出すために必要です。
    
    aws_lambda_function.xxx.invoke_arn の値を渡してください。
    
    Invoke ARN の形式:
    arn:aws:apigateway:{region}:lambda:path/2015-03-31/functions/{lambda-arn}/invocations
    
    ■ ARN の種類と違い
    -----------------------------------------------------------
    | 種類        | 用途                    | 取得方法           |
    |------------|------------------------|-------------------|
    | ARN        | リソースの一意識別        | .arn              |
    | Invoke ARN | API Gateway からの呼び出し | .invoke_arn      |
    | Qualified ARN | バージョン/エイリアス付き | .qualified_arn  |
    -----------------------------------------------------------
  EOT
  type        = string
}

#-------------------------------------------------------------------------------
# オプション変数
#-------------------------------------------------------------------------------

variable "tags" {
  description = <<-EOT
    リソースに付与する追加のタグ。
    モジュール内で自動的に Name と Environment タグが追加されます。
    
    例:
    {
      Project = "order-processing"
      Owner   = "platform-team"
    }
  EOT
  type        = map(string)
  default     = {}
}

#-------------------------------------------------------------------------------
# 高度な設定（将来の拡張用）
#-------------------------------------------------------------------------------

variable "log_retention_days" {
  description = <<-EOT
    CloudWatch Logs の保持期間（日数）。
    
    指定可能な値:
    1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    
    0 を指定すると無期限保持になります。
  EOT
  type        = number
  default     = 30

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days は有効な値である必要があります。"
  }
}

variable "enable_access_logging" {
  description = <<-EOT
    アクセスログを有効にするかどうか。
    
    true: アクセスログを CloudWatch Logs に出力
    false: アクセスログを無効化
    
    本番環境では true を推奨します。
  EOT
  type        = bool
  default     = true
}
