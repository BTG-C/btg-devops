# ==============================================================================
# Production Environment Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for production environment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "btg"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "github_repo" {
  description = "GitHub repository pattern for OIDC"
  type        = string
  default     = "BTG-C/btg-*-mfe"
}

variable "domain_name" {
  description = "Custom domain (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN (optional)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for AWS Budget alerts"
  type        = string
  default     = "devops@btg-company.com"
}
