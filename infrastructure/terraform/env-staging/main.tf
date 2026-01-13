# ==============================================================================
# BTG MFE Infrastructure - Staging Environment
# ==============================================================================
# AWS Account: Production (same account as prod, different environment)
# Region: us-east-1
# Purpose: Pre-production testing with blue-green deployment
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - separate from dev
  backend "s3" {
    bucket         = "btg-terraform-state-prod"
    key            = "mfe-infrastructure/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "btg-terraform-locks-prod"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider - Production Account (Staging Environment)
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  
  # Production AWS Account (staging namespace)
  # Use AWS CLI profile or GitHub OIDC to authenticate
  
  default_tags {
    tags = {
      Project     = "BTG-MFE"
      Environment = "staging"
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
  
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "s3_bucket_name" {
  value = module.mfe_infrastructure.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.mfe_infrastructure.cloudfront_distribution_id
}

output "cloudfront_url" {
  value = module.mfe_infrastructure.cloudfront_url
}

output "github_actions_role_arn" {
  value = module.mfe_infrastructure.github_actions_role_arn
}
