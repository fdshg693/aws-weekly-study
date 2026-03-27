variable "aws_region" {
  description = "Terraform state resources を作成する AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "state 管理リソース名に使うプロジェクト名"
  type        = string
  default     = "terra-prod-s3"
}

variable "state_bucket_name" {
  description = "state 保存用 S3 バケット名。未指定の場合は自動生成"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "state lock 用 DynamoDB テーブル名。未指定の場合は自動生成"
  type        = string
  default     = ""
}

variable "force_destroy_state_bucket" {
  description = "学習用途で bucket 削除を容易にしたい場合のみ true"
  type        = bool
  default     = false
}

variable "tags" {
  description = "追加で付与するタグ"
  type        = map(string)
  default     = {}
}
