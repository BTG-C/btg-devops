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
  instance_count          = 2              # Replica set for HA
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
  ssl_certificate_arn        = var.certificate_arn  # Required for staging
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

# ==============================================================================
# Backend Services
# ==============================================================================

# ------------------------------------------------------------------------------
# 5. Gateway Service (Public ALB)
# ------------------------------------------------------------------------------
module "gateway_service" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  cluster_id       = module.ecs_platform.cluster_id
  service_name     = "gateway-service"
  container_image  = var.gateway_service_image
  container_port   = 8080
  desired_count    = 2
  cpu              = 1024
  memory           = 2048
  
  listener_arn      = var.certificate_arn != "" ? module.ecs_platform.public_https_listener_arn : module.ecs_platform.public_listener_arn
  path_pattern      = "/gateway-service/*"
  listener_priority = 100
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "staging"
    },
    {
      name  = "AUTH_SERVICE_URL"
      value = "http://${module.ecs_platform.internal_alb_dns}"
    }
  ]
  
  secrets = [
    {
      name      = "MONGODB_PASSWORD"
      valueFrom = module.documentdb.master_password_secret_arn
    }
  ]
}

# ------------------------------------------------------------------------------
# 6. Auth Service (Internal ALB)
# ------------------------------------------------------------------------------
module "auth_server" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  cluster_id       = module.ecs_platform.cluster_id
  service_name     = "auth-server"
  container_image  = var.auth_service_image
  container_port   = 8080
  desired_count    = 2
  cpu              = 512
  memory           = 1024
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/auth-server/*"
  listener_priority = 10
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "staging"
    },
    {
      name  = "MONGODB_HOST"
      value = module.documentdb.endpoint
    }
  ]
  
  secrets = [
    {
      name      = "MONGODB_PASSWORD"
      valueFrom = module.documentdb.master_password_secret_arn
    }
  ]
}

# ------------------------------------------------------------------------------
# 7. Score-Odd Service (Internal ALB)
# ------------------------------------------------------------------------------
module "score_odd_service" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  cluster_id       = module.ecs_platform.cluster_id
  service_name     = "score-odd-service"
  container_image  = var.score_odd_service_image
  container_port   = 8080
  desired_count    = 2
  cpu              = 512
  memory           = 1024
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/score-odd-service/*"
  listener_priority = 20
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "staging"
    },
    {
      name  = "MONGODB_HOST"
      value = module.documentdb.endpoint
    }
  ]
  
  secrets = [
    {
      name      = "MONGODB_PASSWORD"
      valueFrom = module.documentdb.master_password_secret_arn
    }
  ]
}

# ------------------------------------------------------------------------------
# 8. Enhancer Service (Internal ALB)
# ------------------------------------------------------------------------------
module "enhancer_service" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  cluster_id       = module.ecs_platform.cluster_id
  service_name     = "enhancer-service"
  container_image  = var.enhancer_service_image
  container_port   = 8080
  desired_count    = 2
  cpu              = 512
  memory           = 1024
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/enhancer-service/*"
  listener_priority = 30
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "staging"
    },
    {
      name  = "MONGODB_HOST"
      value = module.documentdb.endpoint
    }
  ]
  
  secrets = [
    {
      name      = "MONGODB_PASSWORD"
      valueFrom = module.documentdb.master_password_secret_arn
    }
  ]
}

# ------------------------------------------------------------------------------
# 9. Cost Monitoring (AWS Budget)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name              = "btg-staging-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "700"  # $700/month threshold for staging
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80  # Alert at 80% ($560)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100  # Alert at 100% ($700)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = {
    Name = "btg-staging-monthly-budget"
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
