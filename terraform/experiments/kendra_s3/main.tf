# Amazon Kendra: Index + S3 Data Source

resource "aws_kendra_index" "this" {
  name        = var.kendra_index_name
  description = var.kendra_index_description
  edition     = var.kendra_edition

  # Kendra が CloudWatch Logs にログ出力するためのロール
  role_arn = aws_iam_role.kendra_index.arn
}

resource "aws_kendra_data_source" "s3" {
  index_id = aws_kendra_index.this.id
  name     = var.data_source_name
  type     = "S3"

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
    s3_configuration {
      bucket_name = aws_s3_bucket.kendra.bucket

      # 対象プレフィックス配下のみ取り込み
      inclusion_prefixes = [var.s3_inclusion_prefix]
    }
  }
}
