variable "project_name" {}
variable "environment" {}
variable "vpc_id" {}
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
