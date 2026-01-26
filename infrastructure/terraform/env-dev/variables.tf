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

variable "root_domain" {
  description = "Root domain name registered in Route 53"
  type        = string
  default     = "puntedge.com"
}

variable "enable_custom_domain" {
  description = "Enable custom domain and SSL certificate"
  type        = bool
  default     = false  # Set to true when ready to use custom domain
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks (true for dev without NAT, false for staging/prod with NAT)"
  type        = bool
  default     = true  # Dev: true (no NAT Gateway)
}

variable "subdomain" {
  description = "Subdomain for this environment (e.g., 'dev.btg')"
  type        = string
  default     = "dev.btg"
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

# ==============================================================================
# SNS Configuration
# ==============================================================================

variable "sns_admin_emails" {
  description = "List of admin emails to subscribe to SNS topics (optional, for testing)"
  type        = list(string)
  default     = []
  # Example: ["admin@puntedge.com", "devops@puntedge.com"]
}
