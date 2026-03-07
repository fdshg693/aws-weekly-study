# ===========================
# モジュール呼び出し(ここで、変数をモジュールに渡す)
# ===========================

# S3モジュール呼び出し（バケットポリシーなしで先に作成）
module "s3_website" {
  source = "./modules/s3_website"

  bucket_name                  = local.bucket_name
  enable_versioning            = local.is_production
  block_public_access          = var.enable_cloudfront # CloudFront使用時はパブリックアクセスをブロック
  enable_public_access         = !var.enable_cloudfront # CloudFront未使用時のみパブリックアクセス許可
  enable_website_hosting       = !var.enable_cloudfront # CloudFront未使用時のみS3ウェブサイトホスティング有効化
  cloudfront_oac_arn           = "" # 初回作成時は空（CloudFront作成後に別途ポリシー適用）
  cloudfront_distribution_arn  = "" # 初回作成時は空（CloudFront作成後に別途ポリシー適用）
  website_files                = local.website_files
  tags                         = local.common_tags
}

# CloudFrontモジュール呼び出し（有効時のみ）
module "cloudfront" {
  # enable_cloudfrontがtrueのときだけモジュールを作成
  count  = var.enable_cloudfront ? 1 : 0
  source = "./modules/cloudfront"

  distribution_name                = "${var.environment}-static-website"
  s3_bucket_regional_domain_name   = module.s3_website.bucket_regional_domain_name
  origin_id                        = "S3-${local.bucket_name}"
  comment                          = "CloudFront distribution for ${var.environment} static website"
  price_class                      = var.cloudfront_price_class
  aliases                          = var.custom_domain_names
  acm_certificate_arn              = var.acm_certificate_arn
  tags                             = local.common_tags

  # S3モジュールの作成後にCloudFrontを作成するように依存関係を設定
  depends_on = [module.s3_website]
}

# S3バケットポリシー（CloudFront作成後に適用）
resource "aws_s3_bucket_policy" "cloudfront_access" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = module.s3_website.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_website.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront[0].distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront]
}
