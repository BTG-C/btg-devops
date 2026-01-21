# ==============================================================================
# Development Environment Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for development environment"
  type        = string
  default     = "us-east-1"
}

variable "organization" {
  description = "Organization name (short form of PuntEdge)"
  type        = string
  default     = "punt"
}

variable "product" {
  description = "Product name"
  type        = string
  default     = "btg"
}

variable "project_name" {
  description = "Full project name (organization-product-environment)"
  type        = string
  default     = "punt-btg"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
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
