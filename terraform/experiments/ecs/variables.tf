variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ecs-sample"
}

# コンテナ設定
variable "container_port" {
  description = "Port that the container listens on"
  type        = number
  default     = 80
}

variable "container_cpu" {
  description = <<-EOT
    Fargate タスクに割り当てるCPUユニット数。
    有効な組み合わせ:
      256  (.25 vCPU) → メモリ: 512, 1024, 2048
      512  (.5 vCPU)  → メモリ: 1024 〜 4096
      1024 (1 vCPU)   → メモリ: 2048 〜 8192
      2048 (2 vCPU)   → メモリ: 4096 〜 16384
      4096 (4 vCPU)   → メモリ: 8192 〜 30720
  EOT
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Fargate タスクに割り当てるメモリ（MiB）。container_cpu との有効な組み合わせに注意"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "ECS サービスで起動するタスクの希望数"
  type        = number
  default     = 1
}

# セキュリティ設定
variable "allowed_cidrs" {
  description = <<-EOT
    ALBへのアクセスを許可するCIDRブロックのリスト。
    デフォルトは全開放（0.0.0.0/0）だが、本番環境では特定のIPに制限すること。
    例: ["203.0.113.0/32", "198.51.100.0/24"]
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "container_image" {
  description = <<-EOT
    コンテナイメージのURI。
    ECRにプッシュ済みのイメージを指定する。
    空の場合はECRリポジトリのlatestタグを使用する。
  EOT
  type        = string
  default     = ""
}
