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

#-------------------------------------------------------------------------------
# ALB 認証（アプリ無改造で認証するため、ALB 側で OIDC を実施する）
#-------------------------------------------------------------------------------
variable "use_cognito" {
  description = <<-EOT
    true の場合、Cognito User Pool を作成して ALB の OIDC プロバイダーとして使用する。
    false の場合は oidc_* 変数で指定した外部 IdP を使用する。
  EOT
  type        = bool
  default     = false
}

variable "cognito_domain_prefix" {
  description = <<-EOT
    Cognito Hosted UI のドメインプレフィックス。
    https://<prefix>.auth.<region>.amazoncognito.com の形式で公開される。
    AWS 全体でグローバルに一意でなければならない。
    use_cognito = true の場合のみ使用。
  EOT
  type        = string
  default     = ""
}

variable "enable_oidc_auth" {
  description = "true の場合、HTTPS の /mcp* に対して ALB authenticate-oidc を有効にする"
  type        = bool
  default     = false
}

variable "oidc_issuer" {
  description = "OIDC issuer URL"
  type        = string
  default     = "https://example.com"
}

variable "oidc_authorization_endpoint" {
  description = "OIDC authorization endpoint"
  type        = string
  default     = "https://example.com/oauth2/authorize"
}

variable "oidc_token_endpoint" {
  description = "OIDC token endpoint"
  type        = string
  default     = "https://example.com/oauth2/token"
}

variable "oidc_user_info_endpoint" {
  description = "OIDC user info endpoint"
  type        = string
  default     = "https://example.com/oauth2/userinfo"
}

variable "oidc_client_id" {
  description = "OIDC client ID registered for the ALB callback URL"
  type        = string
  default     = "REPLACE_ME"
}

variable "oidc_client_secret" {
  description = "OIDC client secret registered for the ALB callback URL"
  type        = string
  default     = "REPLACE_ME"
  sensitive   = true
}

variable "oidc_scope" {
  description = "Scope requested by ALB when redirecting to the IdP"
  type        = string
  default     = "openid profile email"
}

variable "oidc_session_cookie_name" {
  description = "Cookie name used by ALB for authenticated sessions"
  type        = string
  default     = "AWSELBAuthSessionCookie"
}

variable "oidc_session_timeout" {
  description = "OIDC session timeout in seconds"
  type        = number
  default     = 604800
}

variable "oidc_on_unauthenticated_request" {
  description = "Behavior for unauthenticated requests: authenticate, allow, deny"
  type        = string
  default     = "authenticate"
}

variable "oidc_authentication_request_extra_params" {
  description = "Additional query parameters passed to the OIDC authorization request"
  type        = map(string)
  default     = {}
}

#-------------------------------------------------------------------------------
# サーバーサイド OAuth（Claude Desktop 等の MCP クライアント向け）
#
# ALB の authenticate-oidc はブラウザ前提のリダイレクト認証だが、
# Claude Desktop 等のプログラムクライアントは MCP 仕様準拠の OAuth を必要とする。
# このモードでは ALB は認証せず、MCP サーバー自身が Bearer トークンを検証する。
#
# enable_oidc_auth（ALB 認証）とは排他的に使う。
#-------------------------------------------------------------------------------
variable "enable_server_oauth" {
  description = <<-EOT
    true の場合、MCP サーバー側で OAuth 認証を実装する（Claude Desktop 連携用）。
    ALB の enable_oidc_auth とは排他: 両方 true にはできない。
  EOT
  type        = bool
  default     = false
}
