# ==============================================================================
# Production Environment Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for production environment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "btg"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "github_repo" {
  description = "GitHub repository pattern for OIDC"
  type        = string
  default     = "BTG-C/btg-*-mfe"
}

variable "domain_name" {
  description = "Custom domain (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN (optional)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for AWS Budget alerts"
  type        = string
  default     = "devops@btg-company.com"
}

# ==============================================================================
# Service Container Images
# ==============================================================================

variable "gateway_service_image" {
  description = "Gateway service Docker image (updated by CI/CD)"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}

variable "auth_service_image" {
  description = "Auth server Docker image (updated by CI/CD)"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}

variable "score_odd_service_image" {
  description = "Score-Odd service Docker image (updated by CI/CD)"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}

variable "enhancer_service_image" {
  description = "Enhancer service Docker image (updated by CI/CD)"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}
