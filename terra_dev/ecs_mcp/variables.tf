variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ecs-mcp"
}

#-------------------------------------------------------------------------------
# ネットワーク / 公開設定
#-------------------------------------------------------------------------------
variable "allowed_cidrs" {
  description = <<-EOT
    ALB へのアクセスを許可する CIDR ブロックの一覧。
    学習中は 0.0.0.0/0 でもよいが、本番では必ず絞ること。
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_domain_name" {
  description = <<-EOT
    このサービスに割り当てる公開ドメイン名。
    例: mcp.example.com

    ACM 証明書の CN / SAN と一致する名前を指定する。
    空文字のままでも Terraform 自体は動くが、HTTPS を実用するなら通常は設定する。
  EOT
  type        = string
  default     = ""
}

variable "create_route53_record" {
  description = "true の場合は Route53 に ALB 向けの Alias レコードを作成する"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID（create_route53_record=true の場合に使用）"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = <<-EOT
    HTTPS リスナーに設定する ACM 証明書 ARN。
    ALB と同じリージョンの証明書を指定すること。
  EOT
  type        = string
  default     = "arn:aws:acm:ap-northeast-1:123456789012:certificate/replace-me"
}

#-------------------------------------------------------------------------------
# コンテナ / ECS 設定
#-------------------------------------------------------------------------------
variable "container_port" {
  description = "Container port exposed by the FastMCP wrapper application"
  type        = number
  default     = 8000
}

variable "mcp_path" {
  description = "Path where the MCP streamable HTTP endpoint is exposed"
  type        = string
  default     = "/mcp"
}

variable "container_cpu" {
  description = <<-EOT
    Fargate タスクに割り当てる CPU ユニット数。
    代表的な組み合わせ:
      256  (.25 vCPU) → メモリ: 512, 1024, 2048
      512  (.5 vCPU)  → メモリ: 1024 〜 4096
      1024 (1 vCPU)   → メモリ: 2048 〜 8192
  EOT
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = <<-EOT
    ECS サービスの希望タスク数。
    初回 apply では ECR にイメージがまだ無いことが多いため、0 から始めるのがおすすめ。
  EOT
  type        = number
  default     = 0
}

variable "image_tag" {
  description = "Tag of the image to pull from the ECR repository when container_image is empty"
  type        = string
  default     = "latest"
}

variable "container_image" {
  description = <<-EOT
    ECS タスクで使用するコンテナイメージ URI。
    空文字の場合は、この Terraform が作成する ECR リポジトリの :image_tag を使う。
  EOT
  type        = string
  default     = ""
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention days"
  type        = number
  default     = 30
}

variable "deploy_keycloak_on_aws" {
  description = <<-EOT
    true の場合、この Terraform で Keycloak を AWS 上に構築する。
    構成は ECS Fargate + RDS PostgreSQL + 既存 ALB のパスベースルーティング。
  EOT
  type        = bool
  default     = true
}

variable "keycloak_path" {
  description = <<-EOT
    AWS 管理 Keycloak を公開するパスプレフィックス。
    例: /keycloak
  EOT
  type        = string
  default     = "/keycloak"
}

variable "keycloak_container_image" {
  description = "Container image for the AWS-managed Keycloak service"
  type        = string
  default     = "quay.io/keycloak/keycloak:26.2"
}

variable "keycloak_container_port" {
  description = "Container port exposed by the Keycloak service"
  type        = number
  default     = 8080
}

variable "keycloak_cpu" {
  description = "Fargate CPU units for the Keycloak task"
  type        = number
  default     = 512
}

variable "keycloak_memory" {
  description = "Fargate memory in MiB for the Keycloak task"
  type        = number
  default     = 1024
}

variable "keycloak_desired_count" {
  description = "Desired task count for the Keycloak ECS service"
  type        = number
  default     = 1
}

variable "keycloak_admin_username" {
  description = "Initial Keycloak admin username when deploy_keycloak_on_aws = true"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Initial Keycloak admin password when deploy_keycloak_on_aws = true"
  type        = string
  default     = "REPLACE_ME_KEYCLOAK_ADMIN_PASSWORD"
  sensitive   = true
}

variable "keycloak_db_name" {
  description = "Database name used by the AWS-managed Keycloak instance"
  type        = string
  default     = "keycloak"
}

variable "keycloak_db_username" {
  description = "Database username used by the AWS-managed Keycloak instance"
  type        = string
  default     = "keycloak"
}

variable "keycloak_db_password" {
  description = "Database password used by the AWS-managed Keycloak instance"
  type        = string
  default     = "REPLACE_ME_KEYCLOAK_DB_PASSWORD"
  sensitive   = true
}

variable "keycloak_db_allocated_storage" {
  description = "Allocated storage in GiB for the Keycloak PostgreSQL database"
  type        = number
  default     = 20
}

variable "keycloak_db_instance_class" {
  description = "RDS instance class for the Keycloak PostgreSQL database"
  type        = string
  default     = "db.t3.micro"
}

variable "keycloak_base_url" {
  description = <<-EOT
    外部管理の Keycloak を使う場合の公開ベース URL。
    deploy_keycloak_on_aws = true の場合は https://<public-hostname><keycloak_path> を自動的に使う。
  EOT
  type        = string
  default     = "https://keycloak.example.com"
}

variable "keycloak_realm" {
  description = "Keycloak realm name used for MCP server authorization"
  type        = string
  default     = "mcp"
}

variable "keycloak_public_client_id" {
  description = <<-EOT
    Claude Desktop などの MCP クライアント向けに事前登録した public client の ID。
    keycloak_enable_dynamic_client_registration = false の場合に /oauth/register で返す。
  EOT
  type        = string
  default     = ""
}

variable "keycloak_introspection_client_id" {
  description = "Keycloak token introspection 用の confidential client ID"
  type        = string
  default     = ""
}

variable "keycloak_introspection_client_secret" {
  description = "Keycloak token introspection 用の confidential client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "keycloak_enable_dynamic_client_registration" {
  description = <<-EOT
    true の場合、MCP クライアント向け Authorization Server metadata に
    Keycloak の Dynamic Client Registration endpoint を公開する。
  EOT
  type        = bool
  default     = false
}

variable "oauth_supported_scopes" {
  description = "Scopes advertised by the MCP resource server metadata"
  type        = list(string)
  default     = ["mcp:tools"]
}

variable "oauth_required_scopes" {
  description = "Scopes required to call the MCP endpoint"
  type        = list(string)
  default     = ["mcp:tools"]
}

variable "keycloak_expected_audiences" {
  description = <<-EOT
    Keycloak が発行する access token に含まれているべき audience 一覧。
    空の場合は https://<public-hostname><mcp_path> を期待値として使う。
  EOT
  type        = list(string)
  default     = []
}

#-------------------------------------------------------------------------------
# サーバーサイド OAuth（Claude Desktop 等の MCP クライアント向け）
#
# Claude Desktop 等のプログラムクライアントは MCP 仕様準拠の OAuth を必要とする。
# このプロジェクトでは MCP サーバー自身が Bearer トークンを検証する。
#-------------------------------------------------------------------------------
variable "enable_server_oauth" {
  description = <<-EOT
    true の場合、MCP サーバー側で OAuth 認証を実装する（Claude Desktop 連携用）。
  EOT
  type        = bool
  default     = false
}
