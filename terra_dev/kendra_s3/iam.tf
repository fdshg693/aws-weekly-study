# IAMロール/ポリシー
# - Kendra はサービスプリンシパル（kendra.amazonaws.com）としてロールを AssumeRole し、
#   インデックス作成/同期ジョブ実行/CloudWatch Logs 出力等を行います。
# - ベストプラクティス: インデックス用ロールとデータソース用ロールは分離し、
#   目的ごとに最小権限で付与します（このディレクトリでも分離しています）。

data "aws_iam_policy_document" "kendra_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kendra.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# CloudWatch Logs へ出力するための最小権限（Kendra Index / Data Source で共通利用）
# - Web Crawler が公開サイトを読むだけなら、基本は Logs 権限で動作します。
# - ただし、認証付きサイトをクロールする/プロキシを使う等に拡張する場合は、
#   Secrets Manager 参照権限など追加の IAM 設計が必要になります。
data "aws_iam_policy_document" "kendra_logs" {
  statement {
    effect = "Allow"

    actions = [
      # `Describe*` 系はリソースレベル権限が効かないため `*` が必要。
      # これが無いと `start-data-source-sync-job` 実行時に
      # "Amazon Kendra can't execute the describeLogGroup action..." が発生しうる。
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "kendra_logs" {
  name        = "${var.kendra_index_name}-kendra-logs"
  description = "Allow Amazon Kendra to write logs to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.kendra_logs.json
}

# Index用ロール（主にログ出力用途）
resource "aws_iam_role" "kendra_index" {
  name               = "${var.kendra_index_name}-kendra-index-role"
  assume_role_policy = data.aws_iam_policy_document.kendra_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kendra_index_logs" {
  role       = aws_iam_role.kendra_index.name
  policy_arn = aws_iam_policy.kendra_logs.arn
}

# Data Source用ロール（Web Crawler は公開サイトをクロールするため、基本はログ出力権限で足りる想定）
resource "aws_iam_role" "kendra_data_source" {
  name               = "${var.kendra_index_name}-kendra-datasource-role"
  assume_role_policy = data.aws_iam_policy_document.kendra_assume_role.json
}

resource "aws_iam_role_policy_attachment" "kendra_data_source_logs" {
  role       = aws_iam_role.kendra_data_source.name
  policy_arn = aws_iam_policy.kendra_logs.arn
}

# S3 読み取り権限（Kendra S3 Data Source 用）
# - バケット全体ではなく、指定 prefix 配下のみを最小権限で許可します。
data "aws_iam_policy_document" "kendra_data_source_s3_read" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [aws_s3_bucket.kendra.arn]

    # ListBucket はバケット ARN に対して prefix 条件で絞り込み
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        var.s3_inclusion_prefix,
        "${var.s3_inclusion_prefix}*",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]

    # 指定 prefix 配下のオブジェクトのみ
    resources = ["${aws_s3_bucket.kendra.arn}/${var.s3_inclusion_prefix}*"]
  }
}

resource "aws_iam_policy" "kendra_data_source_s3_read" {
  name        = "${var.kendra_index_name}-kendra-datasource-s3-read"
  description = "Allow Amazon Kendra data source to read documents from S3 (prefix-scoped)"
  policy      = data.aws_iam_policy_document.kendra_data_source_s3_read.json
}

resource "aws_iam_role_policy_attachment" "kendra_data_source_s3_read" {
  role       = aws_iam_role.kendra_data_source.name
  policy_arn = aws_iam_policy.kendra_data_source_s3_read.arn
}
