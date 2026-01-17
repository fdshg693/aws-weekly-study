aws_region  = "ap-northeast-1"
environment = "development"

kendra_index_name        = "kendra-dev-index"
kendra_index_description = "Kendra dev index (Terraform)"
kendra_edition           = "DEVELOPER_EDITION"

data_source_name = "s3-dev"

# Data Source が取り込むコンテンツの主言語（Kendra の言語処理に影響）
# 代表例: "ja", "en", "ko", "zh" など
data_source_language_code = "ja"

# S3 Data Source
s3_bucket_name      = "kendra-s3"
s3_inclusion_prefix = "documents/"

# schedule = "cron(0 3 * * ? *)" # 毎日03:00(UTC)に同期したい場合
