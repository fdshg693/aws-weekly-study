aws_region  = "ap-northeast-1"
environment = "development"

kendra_index_name        = "kendra-dev-index"
kendra_index_description = "Kendra dev index (Terraform)"
kendra_edition           = "DEVELOPER_EDITION"

data_source_name = "webcrawler-dev"

# Data Source が取り込むコンテンツの主言語（Kendra の言語処理に影響）
# 代表例: "ja", "en", "ko", "zh" など
data_source_language_code = "ja"

# クロール開始URL（複数指定可）
# Claude ドキュメントの特定パスのみ取り込む例
seed_urls = [
  "https://platform.claude.com/docs/ja/about-claude/models/overview",
]

# 例: 同一ホスト配下のみ
web_crawler_mode = "HOST_ONLY"

# /about-claude/ 配下に限定
url_inclusion_patterns = [
  ".*platform\\.claude\\.com/docs/ja/about-claude/.*"
]


# 例: /docs 配下のみ取り込む
# url_inclusion_patterns = [
#   "https://example\\.com/docs/.*",
# ]

# 例: /blog は除外
# url_exclusion_patterns = [
#   "https://example\\.com/blog/.*",
# ]

# schedule = "cron(0 3 * * ? *)" # 毎日03:00(UTC)に同期したい場合
