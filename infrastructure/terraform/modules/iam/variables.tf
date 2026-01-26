variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ==============================================================================
# ECS Services Configuration
# ==============================================================================

variable "ecs_services" {
  description = "Map of ECS services and their IAM requirements"
  type = map(object({
    # Task Role Configuration
    enable_task_role = bool
    
    # SNS Permissions
    enable_sns      = optional(bool, false)
    sns_actions     = optional(list(string), ["sns:Publish"])
    sns_topic_arns  = optional(list(string), [])
    
    # S3 Permissions (future)
    enable_s3       = optional(bool, false)
    s3_actions      = optional(list(string), ["s3:GetObject", "s3:PutObject"])
    s3_bucket_arns  = optional(list(string), [])
    
    # DynamoDB Permissions (future)
    enable_dynamodb     = optional(bool, false)
    dynamodb_actions    = optional(list(string), ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"])
    dynamodb_table_arns = optional(list(string), [])
  }))
  
  default = {}
  
  # Example:
  # {
  #   "auth-server" = {
  #     enable_task_role = true
  #     enable_sns       = true
  #     sns_topic_arns   = ["arn:aws:sns:us-east-1:123:topic"]
  #   }
  #   "gateway-service" = {
  #     enable_task_role = false
  #   }
  # }
}

# ==============================================================================
# GitHub Actions OIDC Configuration
# ==============================================================================

variable "enable_github_actions" {
  description = "Enable GitHub Actions OIDC role for MFE deployment"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository pattern for OIDC (e.g., 'owner/repo-*')"
  type        = string
  default     = ""
}

variable "mfe_s3_bucket_arn" {
  description = "ARN of the S3 bucket for MFE hosting"
  type        = string
  default     = ""
}

variable "mfe_cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution for MFE"
  type        = string
  default     = ""
}
