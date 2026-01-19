# ==============================================================================
# BTG MFE Infrastructure - Staging Environment
# ==============================================================================
# AWS Account: Staging (separate account from dev/prod)
# Region: us-east-1
# Purpose: Pre-production testing with blue-green deployment
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - staging account
  backend "s3" {
    bucket         = "btg-terraform-state-staging"
    key            = "mfe-infrastructure/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "btg-terraform-locks-staging"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider - Staging Account
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  
  # Staging AWS Account
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
# 1. Networking Module (VPC, Subnets)
# ------------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.1.0.0/16" # Different CIDR for staging
}

# ------------------------------------------------------------------------------
# 2. DocumentDB Module (Shared Database Cluster)
# ------------------------------------------------------------------------------
module "documentdb" {
  source = "../modules/documentdb"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  subnet_ids              = module.networking.private_subnet_ids
  allowed_security_groups = [module.ecs_platform.ecs_tasks_sg_id]
  
  instance_class          = "db.t3.medium" # Keep cost low for staging
  instance_count          = 1              # Single instance for staging
}

# ------------------------------------------------------------------------------
# 3. ECS Platform Module (Cluster, ALB, Shared Components)
# ------------------------------------------------------------------------------
module "ecs_platform" {
  source = "../modules/ecs-platform"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  vpc_cidr                   = module.networking.vpc_cidr
  public_subnets             = module.networking.public_subnet_ids
  private_subnets            = module.networking.private_subnet_ids
  enable_deletion_protection = true  # Staging: Protect shared environment
}

# ------------------------------------------------------------------------------
# 4. MFE Infrastructure Module (S3, CloudFront)
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
output "vpc_id" {
  value = module.networking.vpc_id
}

output "ecs_cluster_name" {
  value = module.ecs_platform.cluster_name
}

output "public_alb_dns" {
  value = module.ecs_platform.public_alb_dns
}

output "internal_alb_dns" {
  value = module.ecs_platform.internal_alb_dns
}

output "docdb_endpoint" {
  value = module.documentdb.endpoint
}

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
