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

  # language_code: このデータソースが取得するドキュメントの想定言語。
  # - 検索の分かち書き/ステミング等の言語処理に影響します
  # - 例: "ja"(日本語), "en"(英語), "ko"(韓国語), "zh"(中国語)
  # - null の場合はプロバイダー/サービスのデフォルト挙動に従います（言語推定など）
  language_code = var.data_source_language_code

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

      # crawl_depth: Seed URL から辿るリンクの深さ。
      # - 値を上げるほど収集範囲が広がる一方、クロール時間・負荷が増えます
      # - 大きくし過ぎると想定外のページ（例: 検索結果/タグ一覧等）を拾いやすいので
      #   inclusion/exclusion patterns とセットで調整するのが安全です
      crawl_depth = 2

      url_inclusion_patterns = var.url_inclusion_patterns
      url_exclusion_patterns = var.url_exclusion_patterns

      # 代表的な追加オプション（必要になったら変数化して追加すると良い）:
      # - max_urls_per_minute_crawl_rate: クロール速度の上限
      # - max_content_size_per_page_in_mega_bytes: 1ページあたりの取り込み上限
      # - proxy_configuration: 社内ネットワーク経由でクロールする場合
      # - authentication_configuration: ベーシック認証/フォーム認証等が必要な場合
      # - sitemaps: サイトマップ指定
    }
  }
}
