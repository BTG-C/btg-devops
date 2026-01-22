# ==============================================================================
# BTG MFE Infrastructure - Production Environment
# ==============================================================================
# AWS Account: Production (separate account from dev)
# Region: us-east-1
# Purpose: Live customer-facing application with blue-green deployment
# ==============================================================================

# ==============================================================================
# Data Sources
# ==============================================================================

# Get existing Route 53 hosted zone
data "aws_route53_zone" "main" {
  count        = var.enable_custom_domain ? 1 : 0
  name         = var.root_domain
  private_zone = false
}

# ==============================================================================
# Terraform Configuration
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - production isolated
  # NOTE: Backend block does not support variables (Terraform limitation)
  # Region must match var.aws_region but cannot be interpolated here
  backend "s3" {
    bucket         = "punt-terraform-state-prod"
    key            = "btg/prod/terraform.tfstate"
    region         = "us-east-1"  # Must match aws_region variable
    encrypt        = true
    dynamodb_table = "punt-terraform-locks-prod"
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
      Organization = "PuntEdge"
      Product      = "BTG"
      Environment  = "production"
      ManagedBy    = "Terraform"
      CostCenter   = "btg-engineering"
      Owner        = "DevOps"
      Repository   = "btg-devops"
      Compliance   = "Required"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. Networking Module (VPC, Subnets)
# ------------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.2.0.0/16" # Prod CIDR
  enable_nat_gateway = true  # Enable NAT for staging/prod
}

# ------------------------------------------------------------------------------
# 2. ACM Certificate (SSL/TLS) - Optional
# ------------------------------------------------------------------------------
module "acm_certificate" {
  count  = var.enable_custom_domain ? 1 : 0
  source = "../modules/acm-certificate"

  project_name = var.project_name
  environment  = var.environment
  
  domain_name               = "${var.subdomain}.${var.root_domain}"
  subject_alternative_names = []  # Add additional domains if needed
  
  # Safe access: only references when count > 0
  hosted_zone_id = one(data.aws_route53_zone.main[*].zone_id)
}

# ------------------------------------------------------------------------------
# 3. DocumentDB Module (Shared Database Cluster)
# ------------------------------------------------------------------------------
module "documentdb" {
  source = "../modules/documentdb"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  subnet_ids              = module.networking.private_subnet_ids
  allowed_security_groups = [module.ecs_platform.ecs_tasks_sg_id]
  
  master_username         = "btgadmin"
  instance_class          = "db.r6g.large"   # Production-grade ARM-based
  instance_count          = 3                 # 3 nodes for HA + read scaling
  backup_retention_days   = 30                # 30-day retention for production
  skip_final_snapshot     = false             # Always keep final snapshot in prod
}

# ------------------------------------------------------------------------------
# 4. ECS Platform Module (Cluster, ALB, Shared Components)
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
  ssl_certificate_arn        = var.enable_custom_domain ? module.acm_certificate[0].certificate_arn : ""  # REQUIRED for production
}

# ------------------------------------------------------------------------------
# 5. MFE S3 Bucket
# ------------------------------------------------------------------------------
module "mfe_s3" {
  source = "../modules/mfe-s3"
  
  project_name   = var.project_name
  environment    = var.environment
  retention_days = 30  # Production: longer retention
}

# ------------------------------------------------------------------------------
# 6. MFE CloudFront Distribution
# ------------------------------------------------------------------------------
module "mfe_cloudfront" {
  source = "../modules/mfe-cloudfront"
  
  project_name                   = var.project_name
  environment                    = var.environment
  s3_bucket_id                   = module.mfe_s3.bucket_id
  s3_bucket_arn                  = module.mfe_s3.bucket_arn
  s3_bucket_regional_domain_name = module.mfe_s3.bucket_regional_domain_name
  domain_name                    = var.enable_custom_domain ? "${var.subdomain}.${var.root_domain}" : ""
  certificate_arn                = var.enable_custom_domain ? module.acm_certificate[0].certificate_arn : ""
  price_class                    = "PriceClass_All"  # Production: Global
}

# ------------------------------------------------------------------------------
# 7. Route53 DNS Records - Optional
# ------------------------------------------------------------------------------
module "route53" {
  count  = var.enable_custom_domain ? 1 : 0
  source = "../modules/route53"

  # Safe access: only references when count > 0
  hosted_zone_id         = one(data.aws_route53_zone.main[*].zone_id)
  domain_name            = var.root_domain
  subdomain              = var.subdomain
  create_mfe_record      = true
  create_api_record      = false  # Enable when API needs custom domain
  
  cloudfront_domain_name = module.mfe_cloudfront.distribution_domain_name
  cloudfront_zone_id     = "Z2FDTNDATAQYW2"  # CloudFront hosted zone ID
}

# ------------------------------------------------------------------------------
# 8. MFE IAM (GitHub Actions)
# ------------------------------------------------------------------------------
module "mfe_iam" {
  source = "../modules/mfe-iam"
  
  project_name                = var.project_name
  environment                 = var.environment
  github_repo                 = var.github_repo
  s3_bucket_arn               = module.mfe_s3.bucket_arn
  cloudfront_distribution_arn = module.mfe_cloudfront.distribution_arn
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
  desired_count    = 3
  cpu              = 2048
  memory           = 4096
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 10  # Prod: scale to 10 max
  autoscaling_cpu_target   = 60  # Lower threshold for prod
  autoscaling_memory_target = 70
  
  listener_arn      = module.ecs_platform.public_https_listener_arn
  path_pattern      = "/gateway-service/*"
  listener_priority = 100
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "prod"
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
  desired_count    = 3
  cpu              = 1024
  memory           = 2048
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 8  # Prod: auth scales to 8 max
  autoscaling_cpu_target   = 60
  autoscaling_memory_target = 70
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/auth-server/*"
  listener_priority = 10
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "prod"
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
  desired_count    = 3
  cpu              = 2048
  memory           = 4096
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 10  # Prod: scale to 10 max
  autoscaling_cpu_target   = 60
  autoscaling_memory_target = 70
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/score-odd-service/*"
  listener_priority = 20
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "prod"
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
  desired_count    = 3
  cpu              = 2048  # Production: High CPU for streaming + computation
  memory           = 4096  # High memory for streaming buffers + computation
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 8  # Prod: enhancer scales to 8 max
  autoscaling_cpu_target   = 60
  autoscaling_memory_target = 70
  
  listener_arn      = module.ecs_platform.internal_listener_arn
  path_pattern      = "/enhancer-service/*"
  listener_priority = 30
  health_check_path = "/actuator/health"
  
  security_group_id = module.ecs_platform.ecs_tasks_security_group_id
  private_subnets   = module.networking.private_subnet_ids
  
  environment_variables = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "prod"
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
  name              = "punt-btg-prod-monthly-budget"
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
    Name = "punt-btg-prod-monthly-budget"
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
  value = module.mfe_s3.bucket_id
}

output "cloudfront_distribution_id" {
  value = module.mfe_cloudfront.distribution_id
}

output "cloudfront_url" {
  value = module.mfe_cloudfront.distribution_url
}

output "github_actions_role_arn" {
  value = module.mfe_iam.github_actions_role_arn
}
