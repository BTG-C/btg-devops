# ==============================================================================
# BTG MFE Infrastructure - Development Environment
# ==============================================================================
# AWS Account: Development (separate account from staging/prod)
# Region: us-east-1
# Purpose: Development testing and CI/CD validation
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - prevents state conflicts
  backend "s3" {
    bucket         = "btg-terraform-state-dev"
    key            = "mfe-infrastructure/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "btg-terraform-locks-dev"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider - Development Account
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  
  # Development AWS Account
  # Use AWS CLI profile or GitHub OIDC to authenticate
  
  default_tags {
    tags = {
      Project     = "BTG-MFE"
      Environment = "dev"
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Owner       = "DevOps"
    }
  }
}

# ------------------------------------------------------------------------------
# MFE Infrastructure Module
# ------------------------------------------------------------------------------
module "mfe_infrastructure" {
  source = "../modules/shared-mfe"
  
  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment
  github_repo  = var.github_repo
  
  # Development-specific overrides
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
}

# ------------------------------------------------------------------------------
# Outputs (pass-through from module)
# ------------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "S3 bucket name for MFE hosting"
  value       = module.mfe_infrastructure.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.mfe_infrastructure.cloudfront_distribution_id
}

output "cloudfront_url" {
  description = "CloudFront URL"
  value       = module.mfe_infrastructure.cloudfront_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = module.mfe_infrastructure.github_actions_role_arn
}
