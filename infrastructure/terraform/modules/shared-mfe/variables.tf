variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "btg"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository pattern (e.g., owner/repo-*)"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}

# Optional: SSL certificate ARN for custom domain
variable "certificate_arn" {
  description = "SSL Certificate ARN from AWS Certificate Manager (required if using custom domain)"
  type        = string
  default     = ""
}