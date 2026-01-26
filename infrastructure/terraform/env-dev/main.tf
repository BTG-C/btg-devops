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
# Backend: Uses S3 bucket created by infra-setup-pre-terraform
# State Location: s3://punt-terraform-state-dev/btg/dev/terraform.tfstate
# Locking: DynamoDB table punt-terraform-locks-dev prevents concurrent modifications
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Remote state backend - stores state in S3 (created by infra-setup-pre-terraform)
  # This enables team collaboration and prevents state conflicts
  # NOTE: Backend block does not support variables (Terraform limitation)
  backend "s3" {
    bucket         = "punt-terraform-state-dev"      # Created by infra-setup-pre-terraform/dev
    key            = "btg/dev/terraform.tfstate"     # Unique state file path for this environment
    region         = "us-east-1"                     # Must match var.aws_region
    encrypt        = true                             # AES-256 encryption at rest
    dynamodb_table = "punt-terraform-locks-dev"      # State locking table (prevents concurrent updates)
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
# Creates:
#   - VPC with 10.0.0.0/16 CIDR
#   - 2 Public Subnets (for ALBs)
#   - 2 Private Subnets (for ECS tasks, DocumentDB)
#   - Internet Gateway (for public subnet internet access)
#   - NAT Gateway: DISABLED in dev (cost optimization, ECS tasks use public IPs)
# Cost Savings: No NAT Gateway saves $33/month in dev
# Dependencies: None
# ------------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false  # Disable NAT for dev to save $33/month
}

# ------------------------------------------------------------------------------
# 2. MFE S3 Bucket (Frontend Asset Storage)
# ------------------------------------------------------------------------------
# Creates:
#   - S3 bucket for hosting MFE bundles (Shell, Enhancer, etc.)
#   - Versioning enabled (rollback capability)
#   - Server-side encryption (AES-256)
#   - Lifecycle policy: Delete old versions after 7 days (dev)
#   - Public access blocked (CloudFront-only access via OAI)
# Cost: ~$1-5/month depending on storage and data transfer
# Dependencies: None
# ------------------------------------------------------------------------------
module "mfe_s3" {
  source = "../modules/mfe-s3"
  
  project_name   = var.project_name
  environment    = var.environment
  retention_days = 7  # Dev: shorter retention
}

# ------------------------------------------------------------------------------
# 3. ACM Certificate (SSL/TLS) - Optional
# ------------------------------------------------------------------------------
# Creates SSL/TLS certificate for custom domain (e.g., dev.btg.puntedge.com)
# Uses DNS validation via Route 53
# Certificate is used by Public ALB for HTTPS termination
# Dev Default: Disabled (enable_custom_domain = false) to save costs
# Dependencies: data.aws_route53_zone (external)
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
# 4. MFE CloudFront Distribution (CDN)
# ------------------------------------------------------------------------------
# Creates:
#   - CloudFront distribution (global CDN)
#   - Origin: S3 bucket via Origin Access Identity (secure access)
#   - Price Class: PriceClass_100 (US, Canada, Europe - cost-optimized for dev)
#   - Default caching behavior (optimized for static assets)
#   - Custom domain support (optional, disabled in dev by default)
# Access: CloudFront URL (e.g., d1234567890.cloudfront.net)
# Cost: ~$5-10/month (low traffic dev environment)
# Dependencies: mfe_s3, acm_certificate (optional)
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
# 5. Route53 DNS Records - Optional
# ------------------------------------------------------------------------------
# Creates:
#   - A record pointing subdomain to CloudFront (e.g., dev.btg.puntedge.com)
#   - Uses existing Route 53 hosted zone (must be created manually)
# Dev Default: Disabled (enable_custom_domain = false)
# Enable when: Ready to use custom domain instead of CloudFront URL
# Dependencies: mfe_cloudfront
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
# 6. Centralized IAM Module
# ------------------------------------------------------------------------------
# Purpose: Manage all IAM roles and policies in one place
# Creates:
#   - ECS Task Execution Roles (4 services)
#   - ECS Task Roles (application permissions)
#   - GitHub Actions OIDC Role (MFE deployment)
# Benefits: Single source of truth, easier auditing, reusable roles
# Dependencies: mfe_s3, mfe_cloudfront (for GitHub Actions OIDC)
# Note: SNS permissions will be added separately to avoid circular dependency
# ------------------------------------------------------------------------------
module "iam" {
  source = "../modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  
  # ECS Services IAM Configuration
  ecs_services = {
    "gateway-service" = {
      enable_task_role = false  # No AWS SDK calls needed
    }
    "auth-server" = {
      enable_task_role = true
      enable_sns       = false  # Will be added via separate policy below
    }
    "score-odd-service" = {
      enable_task_role = false  # Only uses DocumentDB
    }
    "enhancer-service" = {
      enable_task_role = false  # Only uses DocumentDB
    }
  }
  
  # GitHub Actions OIDC - Now safe to reference (mfe_s3 and mfe_cloudfront created above)
  enable_github_actions            = true
  github_repo                      = var.github_repo
  mfe_s3_bucket_arn                = module.mfe_s3.bucket_arn
  mfe_cloudfront_distribution_arn  = module.mfe_cloudfront.distribution_arn
}

# ------------------------------------------------------------------------------
# 7. SNS Topics for Notifications
# ------------------------------------------------------------------------------
# Authentication notifications topic (for auth-service)
# Used for: User registration, password resets, MFA, login alerts
# Dependencies: None
# ------------------------------------------------------------------------------
module "auth_notifications_topic" {
  source = "../modules/sns"
  
  project_name = var.project_name
  environment  = var.environment
  topic_name   = "auth-notifications"
  display_name = "BTG Auth Service Notifications"
  purpose      = "User authentication events and notifications"
  
  # Optional: Subscribe admin email for testing
  email_subscriptions = var.sns_admin_emails
  
  # Enable encryption
  enable_encryption = true
}

# ------------------------------------------------------------------------------
# 7a. Auth Service SNS Permissions (Separate Policy)
# ------------------------------------------------------------------------------
# Purpose: Add SNS permissions to auth-server task role after SNS topic is created
# This solves the circular dependency (IAM needs SNS ARN, but SNS created after IAM)
# Dependencies: iam (task role), auth_notifications_topic
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "auth_server_sns" {
  name = "${var.project_name}-${var.environment}-auth-server-sns-publish"
  role = module.iam.ecs_task_role_names["auth-server"]
  
  depends_on = [
    module.iam,
    module.auth_notifications_topic
  ]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SNSPublishAccess"
      Effect   = "Allow"
      Action   = ["sns:Publish", "sns:ListTopics"]
      Resource = [module.auth_notifications_topic.topic_arn]
    }]
  })
}

# ------------------------------------------------------------------------------
# 8. ECS Platform Module (Cluster, ALB, Shared Components)
# ------------------------------------------------------------------------------
# Creates:
#   - ECS Fargate Cluster (serverless container orchestration)
#   - Public ALB (for gateway service - internet-facing)
#   - Internal ALB (for auth, score-odd, enhancer - VPC-only)
#   - Security Groups (ALB -> ECS tasks access control)
#   - CloudWatch Container Insights (monitoring)
# Dependencies: networking
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
# 9. DocumentDB Module (MongoDB-Compatible Database)
# ------------------------------------------------------------------------------
# Creates:
#   - DocumentDB cluster (MongoDB 5.0 compatible)
#   - Single instance: db.t4g.medium (ARM-based, cost-optimized)
#   - Master password stored in AWS Secrets Manager
#   - TLS encryption enabled for connections
#   - Automated backups: 1-day retention (dev only)
# Security: Only accessible from ECS tasks security group
# Cost: ~$60/month (single node, minimal for dev)
# Dependencies: networking, ecs_platform (for security group)
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
# 9. Gateway Service (Public ALB)
# ------------------------------------------------------------------------------
# API Gateway service - internet-facing entry point
# Resources:
#   - CPU: 0.25 vCPU (256 units) - Cost-optimized for dev
#   - Memory: 512 MB
#   - Desired Count: 1 task (no auto-scaling in dev)
#   - Public IP: Enabled (required since NAT Gateway disabled)
# Routing: Public ALB -> /gateway-service/* -> This service
# Security: Private subnet + security group (ALB can reach, internet cannot)
# Cost: ~$11/month
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
  cpu              = 256
  memory           = 512
  assign_public_ip = true  # Dev: No NAT Gateway, requires public IP for internet access
  
  # IAM Roles from centralized IAM module
  execution_role_arn = module.iam.ecs_task_execution_role_arns["gateway-service"]
  task_role_arn      = null  # No task role needed (no AWS SDK calls)
  
  # Auto-scaling configuration
  enable_autoscaling       = false
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
# Authentication & authorization service - VPC-internal only
# Resources:
#   - CPU: 0.25 vCPU (256 units) - Cost-optimized for dev
#   - Memory: 512 MB
#   - Desired Count: 1 task (no auto-scaling in dev)
#   - Public IP: Enabled (required since NAT Gateway disabled)
#   - SNS Access: Enabled for sending notifications (registration, password reset, etc.)
# Routing: Internal ALB -> /auth-server/* -> This service
# Security: Accessible only from within VPC (other services)
# Cost: ~$11/month
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
  assign_public_ip = true  # Dev: No NAT Gateway, requires public IP for internet access
  
  # IAM Roles from centralized IAM module (with SNS permissions)
  execution_role_arn = module.iam.ecs_task_execution_role_arns["auth-server"]
  task_role_arn      = module.iam.ecs_task_role_arns["auth-server"]
  
  # Auto-scaling configuration
  enable_autoscaling       = false
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
    },
    {
      name  = "SNS_TOPIC_ARN"
      value = module.auth_notifications_topic.topic_arn
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
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
# 11. Score-Odd Service (Internal ALB)
# ------------------------------------------------------------------------------
# Sports scoring and odds calculation service - VPC-internal only
# Resources:
#   - CPU: 0.25 vCPU (256 units) - Cost-optimized for dev
#   - Memory: 512 MB
#   - Desired Count: 1 task (no auto-scaling in dev)
#   - Public IP: Enabled (required since NAT Gateway disabled)
# Routing: Internal ALB -> /score-odd-service/* -> This service
# Database: Connects to DocumentDB for score/odds data
# Cost: ~$11/month
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
  cpu              = 256
  memory           = 512
  assign_public_ip = true  # Dev: No NAT Gateway, requires public IP for internet access
  
  # IAM Roles from centralized IAM module
  execution_role_arn = module.iam.ecs_task_execution_role_arns["score-odd-service"]
  task_role_arn      = null  # No task role needed (only DocumentDB)
  
  # Auto-scaling configuration
  enable_autoscaling       = false
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
# Data enhancement and enrichment service - VPC-internal only
# Resources:
#   - CPU: 0.25 vCPU (256 units) - Cost-optimized for dev
#   - Memory: 512 MB
#   - Desired Count: 1 task (no auto-scaling in dev)
#   - Public IP: Enabled (required since NAT Gateway disabled)
# Routing: Internal ALB -> /enhancer-service/* -> This service
# Note: Production uses higher resources for I/O + CPU intensive streaming
# Cost: ~$11/month
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
  cpu              = 256   # Dev: Reduced for cost optimization
  memory           = 512   # Dev: Reduced for cost optimization
  assign_public_ip = true  # Dev: No NAT Gateway, requires public IP for internet access
  
  # IAM Roles from centralized IAM module
  execution_role_arn = module.iam.ecs_task_execution_role_arns["enhancer-service"]
  task_role_arn      = null  # No task role needed (only DocumentDB)
  
  # Auto-scaling configuration
  enable_autoscaling       = false
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
# Budget: $500/month (comfortable margin above ~$150-170 actual dev costs)
# Alerts:
#   - 80% ($400): Warning - approaching budget limit
#   - 100% ($500): Critical - budget exceeded
# Notifications: Email sent to var.alert_email
# Purpose: Prevent unexpected cost overruns, detect resource leaks
# Actual Dev Cost: ~$150-170/month (ECS $44 + DocumentDB $60 + ALB $32 + misc)
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
  value       = module.iam.github_actions_role_arn
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

output "sns_auth_topic_arn" {
  description = "ARN of the auth notifications SNS topic"
  value       = module.auth_notifications_topic.topic_arn
}

output "iam_summary" {
  description = "Summary of IAM roles created"
  value       = module.iam.iam_summary
}
