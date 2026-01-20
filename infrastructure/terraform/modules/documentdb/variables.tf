variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to connect to DocumentDB"
  type        = list(string)
  default     = []
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "btgadmin"
}

variable "instance_class" {
  description = "The instance class to use"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destruction"
  type        = bool
  default     = false
}

variable "databases" {
  description = "Map of databases to create with their own credentials"
  type = map(object({
    username    = string
    description = string
  }))
  default = {
    btg_auth = {
      username    = "btgauth"
      description = "Authentication and user management database"
    }
    btg = {
      username    = "btgapp"
      description = "Main business logic database"
    }
  }
}
