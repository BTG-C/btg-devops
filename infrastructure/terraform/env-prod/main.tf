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
# 1. Networking Module (VPC, Subnets)
# ------------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.2.0.0/16" # Prod CIDR
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
  
  instance_class          = "db.r5.large" # Production grade instance
  instance_count          = 2             # High Availability
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
  enable_deletion_protection = true  # Production: Prevent accidental ALB deletion
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
# 5. Cost Monitoring (AWS Budget)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name              = "btg-prod-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "1000"  # $1000/month threshold
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80  # Alert at 80% ($800)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100  # Alert at 100% ($1000)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 120  # Alert at 120% ($1200) - overspend
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = {
    Name = "btg-prod-monthly-budget"
  }
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
