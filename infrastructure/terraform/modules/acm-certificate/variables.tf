# ==============================================================================
# ACM Certificate Module Variables
# ==============================================================================

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names to include in certificate (SANs)"
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for DNS validation"
  type        = string
}

variable "required_region" {
  description = "Required AWS region for certificate (us-east-1 for CloudFront, any for ALB)"
  type        = string
  default     = "us-east-1"  # Default for CloudFront certificates
}
