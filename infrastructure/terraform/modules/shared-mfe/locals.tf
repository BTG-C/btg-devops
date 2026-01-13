# ==============================================================================
# DATA SOURCES & LOCAL VALUES
# ==============================================================================

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

# Check if GitHub OIDC provider already exists
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ==============================================================================
# LOCAL VALUES
# ==============================================================================
# Local values for computed resource names and configuration

locals {
  # Feature flags based on input variables
  has_custom_domain = var.domain_name != ""
  has_certificate   = var.certificate_arn != ""
  
  # Blue-green deployment enabled only for staging and production
  enable_blue_green = contains(["staging", "prod"], var.environment)
  
  # Environment-specific configurations (simplified for production)
  environment_config = {
    retention_days = var.environment == "prod" ? 30 : 7
    price_class    = var.environment == "prod" ? "PriceClass_All" : "PriceClass_100"
    enable_kms     = false  # Simplified: Use S3-managed encryption for all environments
  }
  
  # AWS CloudFront cache policies (AWS managed)
  cache_policies = {
    disabled  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
  }
  
  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Architecture = "Shell-MFE"
  }
}