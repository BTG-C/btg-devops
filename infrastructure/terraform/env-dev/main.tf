# ==============================================================================
# BTG MFE Infrastructure - Development Environment
# ==============================================================================
# AWS Account: Development (separate account from staging/prod)
# Region: us-east-1
# Purpose: Development testing and CI/CD validation
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
  
  # Remote state backend - prevents state conflicts
  # NOTE: Backend block does not support variables (Terraform limitation)
  # Region must match var.aws_region but cannot be interpolated here
  backend "s3" {
    bucket         = "punt-terraform-state-dev"
    key            = "btg/dev/terraform.tfstate"
    region         = "us-east-1"  # Must match aws_region variable
    encrypt        = true
    dynamodb_table = "punt-terraform-locks-dev"
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
      Organization = "PuntEdge"
      Product      = "BTG"
      Environment  = "dev"
      ManagedBy    = "Terraform"
      CostCenter   = "btg-engineering"
      Owner        = "DevOps"
      Repository   = "btg-devops"
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
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false  # Disable NAT for dev to save $33/month
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
  instance_class          = "db.t4g.medium"      # ARM-based (cheaper)
  instance_count          = 1                     # Single node for dev (saves $55/month)
  backup_retention_days   = 1                     # 1-day retention for dev
  skip_final_snapshot     = true                  # Dev only - prod should be false
}

# ------------------------------------------------------------------------------
# 4. ECS Platform Module (Cluster, ALB, Shared Components)
# ------------------------------------------------------------------------------
module "ecs_platform" {
  source = "../modules/ecs-platform"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  vpc_cidr               = module.networking.vpc_cidr
  public_subnets         = module.networking.public_subnet_ids
  private_subnets        = module.networking.private_subnet_ids
  ssl_certificate_arn    = var.enable_custom_domain ? module.acm_certificate[0].certificate_arn : ""  # Optional for dev
}

# ------------------------------------------------------------------------------
# 5. MFE S3 Bucket
# ------------------------------------------------------------------------------
module "mfe_s3" {
  source = "../modules/mfe-s3"
  
  project_name   = var.project_name
  environment    = var.environment
  retention_days = 7  # Dev: shorter retention
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
  price_class                    = "PriceClass_100"  # Dev: US/Europe only
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

# ------------------------------------------------------------------------------
# 9. Gateway Service (Public ALB)
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
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 3  # Dev: scale to max 3 tasks
  autoscaling_cpu_target   = 70 # Scale when CPU > 70%
  autoscaling_memory_target = 80
  
  listener_arn      = var.enable_custom_domain ? module.ecs_platform.public_https_listener_arn : module.ecs_platform.public_listener_arn
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
# 10. Auth Service (Internal ALB)
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
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2  # Dev: auth scales to 2 max
  autoscaling_cpu_target   = 70
  autoscaling_memory_target = 80
  
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
# 11. Score Odd Service (Internal ALB)
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
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 3  # Dev: scale to max 3 tasks
  autoscaling_cpu_target   = 70
  autoscaling_memory_target = 80
  
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
# 12. Enhancer Service (Internal ALB)
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
  cpu              = 512   # Increased: I/O + CPU intensive (streaming + computation)
  memory           = 1024  # Increased: Needs memory for streaming buffers
  
  # Auto-scaling configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2  # Dev: enhancer scales to 2 max
  autoscaling_cpu_target   = 70
  autoscaling_memory_target = 80
  
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
# 13. Cost Monitoring (AWS Budget)
# ------------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name              = "punt-btg-dev-monthly-budget"
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
    Name = "punt-btg-dev-monthly-budget"
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
  value       = module.mfe_s3.bucket_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.mfe_cloudfront.distribution_id
}

output "cloudfront_url" {
  description = "CloudFront URL"
  value       = module.mfe_cloudfront.distribution_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = module.mfe_iam.github_actions_role_arn
}

output "certificate_arn" {
  description = "ACM certificate ARN (if custom domain enabled)"
  value       = var.enable_custom_domain ? module.acm_certificate[0].certificate_arn : ""
}

output "custom_domain_url" {
  description = "Custom domain URL (if enabled)"
  value       = var.enable_custom_domain ? "https://${var.subdomain}.${var.root_domain}" : module.mfe_cloudfront.distribution_url
}

output "dns_name_servers" {
  description = "Route 53 name servers (for domain verification)"
  value       = var.enable_custom_domain ? one(data.aws_route53_zone.main[*].name_servers) : []
}
