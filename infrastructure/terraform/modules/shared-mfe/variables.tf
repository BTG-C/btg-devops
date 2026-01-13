# ==============================================================================
# INPUT VARIABLES
# ==============================================================================
# These variables can be customized for each environment deployment

# AWS region where resources will be created
variable "aws_region" {
  description = "AWS region for deployment (e.g., us-east-1, eu-west-1)"
  type        = string
  default     = "us-east-1"
}

# Project name used for resource naming and tags
variable "project_name" {
  description = "Project name for resource naming (lowercase, alphanumeric, hyphens only)"
  type        = string
  default     = "angular-mfe"
  
  # Validate project name format for AWS resource naming
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

# Environment name (dev, staging, or prod)
variable "environment" {
  description = "Environment name - determines resource configuration and naming"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# GitHub repository for OIDC trust relationship
variable "github_repo" {
  description = "GitHub repository in format owner/repo-name (e.g., myorg/my-angular-app)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$", var.github_repo))
    error_message = "GitHub repository must be in format 'owner/repo-name'."
  }
}

# Optional: Custom domain name for CloudFront
variable "domain_name" {
  description = "Custom domain name for CloudFront distribution (optional)"
  type        = string
  default     = ""
}

# Optional: SSL certificate ARN for custom domain
variable "certificate_arn" {
  description = "SSL Certificate ARN from AWS Certificate Manager (required if using custom domain)"
  type        = string
  default     = ""
}