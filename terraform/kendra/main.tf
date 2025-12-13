# Amazon Kendra: Index + Web Crawler Data Source

resource "aws_kendra_index" "this" {
  name        = var.kendra_index_name
  description = var.kendra_index_description
  edition     = var.kendra_edition

  # Kendra が CloudWatch Logs にログ出力するためのロール
  role_arn = aws_iam_role.kendra_index.arn
}

resource "aws_kendra_data_source" "webcrawler" {
  index_id = aws_kendra_index.this.id
  name     = var.data_source_name
  type     = "WEBCRAWLER"

  # Kendra がクロール＆同期ジョブを実行するためのロール
  role_arn = aws_iam_role.kendra_data_source.arn

  # 任意: 定期同期（cron）
  schedule = var.schedule

  configuration {
    web_crawler_configuration {
      urls {
        seed_url_configuration {
          seed_urls        = var.seed_urls
          web_crawler_mode = var.web_crawler_mode
        }
      }

      url_inclusion_patterns = var.url_inclusion_patterns
      url_exclusion_patterns = var.url_exclusion_patterns
    }
  }
}
