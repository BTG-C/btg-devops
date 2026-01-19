variable "aws_region" {}
variable "project_name" {}
variable "environment" {}
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for the Public ALB"
  type        = string
}
