# CloudFront Module Outputs

output "distribution_id" {
  description = "CloudFront DistributionのID"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "distribution_arn" {
  description = "CloudFront DistributionのARN"
  value       = aws_cloudfront_distribution.s3_distribution.arn
}

output "distribution_domain_name" {
  description = "CloudFront Distributionのドメイン名"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront DistributionのHosted Zone ID"
  value       = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
}

output "oac_id" {
  description = "Origin Access ControlのID"
  value       = aws_cloudfront_origin_access_control.s3_oac.id
}

output "oac_arn" {
  description = "Origin Access ControlのARN"
  value       = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:origin-access-control/${aws_cloudfront_origin_access_control.s3_oac.id}"
}

data "aws_caller_identity" "current" {}
