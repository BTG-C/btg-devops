# ==============================================================================
# OUTPUT VALUES
# ==============================================================================

# Primary Outputs
output "s3_bucket_name" {
  description = "S3 bucket name where MFEs and shell application are hosted"
  value       = aws_s3_bucket.mfe_assets.id
  sensitive   = false
}

output "cloudfront_distribution_id" {
  description = "Shell CloudFront distribution ID for cache invalidation in CI/CD"
  value       = aws_cloudfront_distribution.mfe_distribution.id
  sensitive   = false
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (auto-generated AWS domain)"
  value       = aws_cloudfront_distribution.mfe_distribution.domain_name
  sensitive   = false
}

output "cloudfront_url" {
  description = "Complete HTTPS URL for accessing the deployed Angular MFE"
  value       = "https://${aws_cloudfront_distribution.mfe_distribution.domain_name}"
  sensitive   = false
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions_role.arn
  sensitive   = false
}

# Environment Information
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
  sensitive   = false
}

output "environment" {
  description = "Deployment environment (dev/staging/prod)"
  value       = var.environment
  sensitive   = false
}

# Blue-Green Deployment Outputs
output "blue_green_enabled" {
  description = "Whether blue-green deployment is enabled for this environment"
  value       = local.enable_blue_green
  sensitive   = false
}

output "s3_bucket_name_green" {
  description = "S3 bucket name for green environment (blue-green deployment)"
  value       = local.enable_blue_green ? aws_s3_bucket.mfe_bucket_green[0].id : null
  sensitive   = false
}

output "cloudfront_distribution_id_green" {
  description = "CloudFront distribution ID for green environment"
  value       = local.enable_blue_green ? aws_cloudfront_distribution.mfe_distribution_green[0].id : null
  sensitive   = false
}

output "cloudfront_domain_name_green" {
  description = "CloudFront domain name for green environment"
  value       = local.enable_blue_green ? aws_cloudfront_distribution.mfe_distribution_green[0].domain_name : null
  sensitive   = false
}

output "active_environment_parameter" {
  description = "SSM parameter name for tracking active environment"
  value       = local.enable_blue_green ? aws_ssm_parameter.active_environment[0].name : null
  sensitive   = false
}

# Security Information
output "encryption_type" {
  description = "Encryption type used for S3 buckets"
  value       = "S3-Managed (AES256)"
  sensitive   = false
}