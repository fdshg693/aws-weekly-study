# CloudFrontキャッシュ無効化
#
# 学習ポイント：
# - TerraformでのCloudFrontキャッシュ無効化
# - null_resourceとlocal-execプロビジョナー
# - AWS CLIとの連携
# - トリガーによる自動実行

# キャッシュ無効化を手動でトリガーするための変数
variable "cache_invalidation_trigger" {
  description = "Change this value to trigger cache invalidation"
  type        = string
  default     = "2025-10-19-v1" # 更新時に変更
}

# AWS CLIを使用したキャッシュ無効化
# 注意：local-execはTerraform実行環境でコマンドを実行
resource "null_resource" "invalidate_cache" {
  # トリガー条件：この値が変わったら再実行
  triggers = {
    invalidation_trigger = var.cache_invalidation_trigger
    distribution_id      = aws_cloudfront_distribution.static_website.id
  }

  # AWS CLIでキャッシュ無効化リクエスト
  provisioner "local-exec" {
    command = <<-EOT
      aws cloudfront create-invalidation \
        --distribution-id ${aws_cloudfront_distribution.static_website.id} \
        --paths "/*"
    EOT
  }

  # CloudFrontディストリビューションが存在することを確認
  depends_on = [aws_cloudfront_distribution.static_website]
}

# 特定パスのみ無効化する例
resource "null_resource" "invalidate_specific_paths" {
  count = 0 # デフォルトは無効（使用時にcountを1に変更）

  triggers = {
    paths = join(",", var.invalidation_paths)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws cloudfront create-invalidation \
        --distribution-id ${aws_cloudfront_distribution.static_website.id} \
        --paths ${join(" ", var.invalidation_paths)}
    EOT
  }
}

variable "invalidation_paths" {
  description = "Specific paths to invalidate"
  type        = list(string)
  default     = ["/index.html", "/style.css", "/app.js"]
}

# Terraformの外部データソースで無効化ステータス確認
data "external" "invalidation_status" {
  count = 0 # 必要時に有効化

  program = ["bash", "-c", <<-EOT
    INVALIDATION_ID=$(aws cloudfront list-invalidations \
      --distribution-id ${aws_cloudfront_distribution.static_website.id} \
      --max-items 1 \
      --query 'InvalidationList.Items[0].Id' \
      --output text)
    
    STATUS=$(aws cloudfront get-invalidation \
      --distribution-id ${aws_cloudfront_distribution.static_website.id} \
      --id $INVALIDATION_ID \
      --query 'Invalidation.Status' \
      --output text)
    
    echo "{\"invalidation_id\":\"$INVALIDATION_ID\",\"status\":\"$STATUS\"}"
  EOT
  ]
}

# 実践的なキャッシュ無効化パターン
locals {
  # 無効化が必要なファイル拡張子
  cache_invalidation_patterns = [
    "/*.html",
    "/*.css",
    "/*.js",
    "/assets/*"
  ]

  # 環境別の無効化戦略
  invalidation_strategy = {
    development = "/*"              # 全て無効化
    staging     = "/*.html"         # HTMLのみ
    production  = "/index.html"     # トップページのみ
  }
}

# Terraformコマンド例をコメントで記載
# terraform apply -var='cache_invalidation_trigger=2025-10-19-v2'
# terraform apply -var='invalidation_paths=["/index.html","/about.html"]'

# 出力
output "cache_invalidation_command" {
  description = "Manual cache invalidation command"
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.static_website.id} --paths '/*'"
}

output "last_invalidation_trigger" {
  description = "Last cache invalidation trigger value"
  value       = var.cache_invalidation_trigger
}
