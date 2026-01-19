variable "project_name" {}
variable "environment" {}
variable "aws_region" {}
variable "vpc_id" {}
variable "cluster_id" {}
variable "service_name" {}
variable "container_image" {}
variable "container_port" {
  default = 8080
}
variable "cpu" {
  default = 256
}
variable "memory" {
  default = 512
}
variable "desired_count" {
  default = 1
}
variable "health_check_path" {
  default = "/actuator/health"
}
variable "listener_arn" {
  description = "ARN of the ALB listener to attach the service to"
  type        = string
}
variable "path_pattern" {}
variable "listener_priority" {}
variable "security_group_id" {}
variable "private_subnets" {
  type = list(string)
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
