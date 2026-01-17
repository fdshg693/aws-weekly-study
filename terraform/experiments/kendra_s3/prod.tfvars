aws_region  = "ap-northeast-1"
environment = "production"

kendra_index_name        = "kendra-prod-index"
kendra_index_description = "Kendra prod index (Terraform)"
kendra_edition           = "DEVELOPER_EDITION"

data_source_name = "s3-prod"

# 取り込むサイトの言語に合わせて設定（未設定にするなら null）
# data_source_language_code = "ja"

# S3 Data Source
s3_bucket_name      = "kendra-s3"
s3_inclusion_prefix = "documents/"

# schedule = "cron(0 2 * * ? *)" # 例: 毎日02:00(UTC)
