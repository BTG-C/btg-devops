output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.mfe_distribution.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.mfe_distribution.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.mfe_distribution.domain_name
}

output "distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.mfe_distribution.domain_name}"
}
