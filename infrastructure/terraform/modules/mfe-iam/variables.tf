variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository pattern (e.g., owner/repo-*)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  type        = string
}
