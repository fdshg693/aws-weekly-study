aws_region  = "ap-northeast-1"
environment = "development"

kendra_index_name        = "kendra-dev-index"
kendra_index_description = "Kendra dev index (Terraform)"
kendra_edition           = "DEVELOPER_EDITION"

data_source_name = "webcrawler-dev"

# クロール開始URL（複数指定可）
seed_urls = [
  "https://example.com/",
]

# 例: 同一ホスト配下のみ
web_crawler_mode = "HOST_ONLY"

# 例: /docs 配下のみ取り込む
url_inclusion_patterns = [
  "https://example\\.com/docs/.*",
]

# 例: /blog は除外
url_exclusion_patterns = [
  "https://example\\.com/blog/.*",
]

# schedule = "cron(0 3 * * ? *)" # 毎日03:00(UTC)に同期したい場合
