variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain old versions"
  type        = number
  default     = 7
}
