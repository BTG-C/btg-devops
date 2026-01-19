# ==============================================================================
# Development Environment Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for development environment"
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

# ------------------------------------------------------------------------------
# Backend Service Variables
# ------------------------------------------------------------------------------
variable "auth_service_image" {
  description = "Docker image for Auth Service"
  default     = "nginx:latest" # Placeholder until real image is built
}

variable "gateway_service_image" {
  description = "Docker image for Gateway Service"
  default     = "nginx:latest" # Placeholder
}

variable "score_odd_service_image" {
  description = "Docker image for Score Odd Service"
  default     = "nginx:latest" # Placeholder
}

variable "enhancer_service_image" {
  description = "Docker image for Enhancer Service"
  default     = "nginx:latest" # Placeholder
}
