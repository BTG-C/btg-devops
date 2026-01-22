variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}
variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALBs (should be true for production)"
  type        = bool
  default     = false
}
variable "ssl_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener on Public ALB (optional for dev, required for prod/staging)"
  type        = string
  default     = ""
}
