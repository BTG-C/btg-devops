# ==============================================================================
# BTG MFE Infrastructure - Production Environment
# ==============================================================================
# AWS Account: Production (separate account from dev)
# Region: us-east-1
# Purpose: Live customer-facing application with blue-green deployment
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - production isolated
  backend "s3" {
    bucket         = "btg-terraform-state-prod"
    key            = "mfe-infrastructure/prod/terraform.tfstate"
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
# AWS Provider - Production Account
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  
  # Production AWS Account
  # Use AWS CLI profile or GitHub OIDC to authenticate
  
  default_tags {
    tags = {
      Project     = "BTG-MFE"
      Environment = "production"
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Owner       = "DevOps"
      Compliance  = "Required"
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
