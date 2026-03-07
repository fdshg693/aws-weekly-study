aws_region  = "ap-northeast-1"
environment = "production"

kendra_index_name        = "kendra-prod-index"
kendra_index_description = "Kendra prod index (Terraform)"
kendra_edition           = "DEVELOPER_EDITION"

data_source_name = "webcrawler-prod"

# 取り込むサイトの言語に合わせて設定（未設定にするなら null）
# data_source_language_code = "en"

seed_urls = [
  "https://example.com/",
]

web_crawler_mode = "HOST_ONLY"

url_inclusion_patterns = []
url_exclusion_patterns = []

# schedule = "cron(0 2 * * ? *)" # 例: 毎日02:00(UTC)
