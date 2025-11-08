# リダイレクト専用バケット
#
# 学習ポイント：
# - S3バケットのリダイレクト機能
# - www有り/無しの統一
# - ウェブサイト設定のリダイレクトルール

# www → non-www（または逆）へのリダイレクト用バケット
resource "aws_s3_bucket" "redirect" {
  count = var.use_custom_domain ? 1 : 0

  bucket = "www.${var.domain_name}"

  tags = {
    Name        = "Redirect Bucket"
    Environment = "Learning"
    Purpose     = "www_redirect"
  }
}

# リダイレクト設定
resource "aws_s3_bucket_website_configuration" "redirect" {
  count = var.use_custom_domain ? 1 : 0

  bucket = aws_s3_bucket.redirect[0].id

  # すべてのリクエストを別のホストにリダイレクト
  redirect_all_requests_to {
    host_name = var.domain_name
    protocol  = "https"
  }
}

# 高度なリダイレクトルール例（コメントアウト）
# resource "aws_s3_bucket_website_configuration" "advanced_redirect" {
#   bucket = aws_s3_bucket.redirect[0].id
#
#   index_document {
#     suffix = "index.html"
#   }
#
#   # 条件付きリダイレクトルール
#   routing_rules = jsonencode([
#     {
#       Condition = {
#         KeyPrefixEquals = "old-path/"
#       }
#       Redirect = {
#         ReplaceKeyPrefixWith = "new-path/"
#         HttpRedirectCode     = "301"
#       }
#     },
#     {
#       Condition = {
#         HttpErrorCodeReturnedEquals = "404"
#       }
#       Redirect = {
#         HostName             = var.domain_name
#         ReplaceKeyWith       = "error.html"
#         HttpRedirectCode     = "302"
#       }
#     }
#   ])
# }

# routing_rulesの別表現（Terraform向け）
locals {
  routing_rules_example = [
    {
      condition = {
        key_prefix_equals = "docs/"
      }
      redirect = {
        replace_key_prefix_with = "documentation/"
        http_redirect_code      = "301"
      }
    },
    {
      condition = {
        http_error_code_returned_equals = "404"
      }
      redirect = {
        replace_key_with = "404.html"
      }
    }
  ]
}
