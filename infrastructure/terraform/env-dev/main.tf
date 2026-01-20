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
# 1. Networking Module (VPC, Subnets)
# ------------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = "10.0.0.0/16" 
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
  
  master_username         = "btgadmin"
  instance_class          = "db.t3.medium"
  instance_count          = 2 # Replica set for HA
  skip_final_snapshot     = true # Dev only - prod should be false
}

# ------------------------------------------------------------------------------
# 3. ECS Platform Module (Cluster, ALB, Shared Components)
# ------------------------------------------------------------------------------
module "ecs_platform" {
  source = "../modules/ecs-platform"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  vpc_cidr               = module.networking.vpc_cidr
  public_subnets         = module.networking.public_subnet_ids
  private_subnets        = module.networking.private_subnet_ids
  ssl_certificate_arn    = var.certificate_arn  # Optional for dev
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
  
  # Development-specific overrides
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
}

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
  desired_count    = 1
  cpu              = 512
  memory           = 1024
  
  listener_arn      = var.certificate_arn != "" ? module.ecs_platform.public_https_listener_arn : module.ecs_platform.public_listener_arn
  path_pattern      = "/gateway-service/*"
  listener_priority = 100
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "dev"
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
module "auth_service" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  cluster_id       = module.ecs_platform.cluster_id
  service_name     = "auth-server"
  container_image  = var.auth_service_image
  container_port   = 8080
  desired_count    = 1
  cpu              = 256
  memory           = 512
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/auth-server/*"
  listener_priority = 10
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "dev"
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
# 7. Score Odd Service (Internal ALB)
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
  desired_count    = 1
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
      value = "dev"
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
  desired_count    = 1
  cpu              = 256
  memory           = 512
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/enhancer-service/*"
  listener_priority = 30
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "dev"
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
  name              = "btg-dev-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "500"  # $500/month threshold for dev
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80  # Alert at 80% ($400)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100  # Alert at 100% ($500)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = {
    Name = "btg-dev-monthly-budget"
  }
}

# ------------------------------------------------------------------------------
# Outputs (pass-through from module)
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
