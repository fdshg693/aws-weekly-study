# ==============================
# ローカル変数の定義
# - 命名規則の一元化
# - 環境差分の集約
# - 共通タグとリソース別タグの定義
# - MIMEタイプマッピングと website 配下ファイル一覧
# ==============================

data "aws_caller_identity" "current" {}

locals {
  normalized_project = trim(replace(lower(var.project_name), "/[^a-z0-9-]/", "-"), "-")

  env_config = {
    development = {
      label                    = "development"
      delivery_mode            = "s3_public"
      website_enabled          = true
      public_read_enabled      = true
      enforce_secure_transport = false
      versioning_status        = "Suspended"
    }
    staging = {
      label                    = "staging"
      delivery_mode            = "cloudfront_private"
      website_enabled          = false
      public_read_enabled      = false
      enforce_secure_transport = true
      versioning_status        = "Enabled"
    }
    production = {
      label                    = "production"
      delivery_mode            = "cloudfront_private"
      website_enabled          = false
      public_read_enabled      = false
      enforce_secure_transport = true
      versioning_status        = "Enabled"
    }
  }

  current_env = local.env_config[var.environment]

  naming_context = {
    project     = local.normalized_project
    environment = local.current_env.label
    account_id  = data.aws_caller_identity.current.account_id
    region      = var.aws_region
  }

  name_prefix = join("-", [
    local.naming_context.project,
    local.naming_context.environment,
    local.naming_context.account_id,
    local.naming_context.region,
  ])

  resource_names = {
    static_website = "${local.name_prefix}-site"
    access_logs    = "${local.name_prefix}-logs"
  }

  bucket_name     = local.resource_names.static_website
  log_bucket_name = local.resource_names.access_logs

  default_tags = merge(
    {
      ManagedBy    = "Terraform"
      Project      = local.normalized_project
      Environment  = local.current_env.label
      DeliveryMode = local.current_env.delivery_mode
    },
    var.tags,
  )

  resource_tags = {
    static_website = {
      Name         = local.resource_names.static_website
      Purpose      = "static website content"
      ResourceRole = "site"
    }
    access_logs = {
      Name         = local.resource_names.access_logs
      Purpose      = "access log storage"
      ResourceRole = "logs"
    }
  }

  s3_access_log_prefix         = "s3-access/"
  cloudfront_access_log_prefix = "cloudfront/"

  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "svg"  = "image/svg+xml"
    "txt"  = "text/plain"
    "xml"  = "application/xml"
    "ico"  = "image/x-icon"
  }

  website_files = fileset("${path.module}/website", "**/*")
}
