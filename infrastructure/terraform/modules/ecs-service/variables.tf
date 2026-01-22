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

variable "vpc_id" {
  description = "VPC ID where the service will be deployed"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}
variable "container_port" {
  description = "Container port to expose"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units for the task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of task instances"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/actuator/health"
}
variable "listener_arn" {
  description = "ARN of the ALB listener to attach the service to"
  type        = string
}

variable "path_pattern" {
  description = "Path pattern for ALB routing (e.g., '/service/*')"
  type        = string
}

variable "listener_priority" {
  description = "ALB listener rule priority (must be unique)"
  type        = number
}

variable "security_group_id" {
  description = "Security group ID for the ECS tasks"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for task placement"
  type        = list(string)
}
variable "environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "List of secrets to inject into the container (from Secrets Manager or SSM)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "enable_autoscaling" {
  description = "Enable auto-scaling for the ECS service"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}
