# ==============================================================================
# Variables for Backend State Setup - Staging
# ==============================================================================

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "punt"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}
