# ==============================================================================
# Route 53 Module Variables
# ==============================================================================

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., puntedge.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for MFE (e.g., 'dev.btg' for dev.btg.puntedge.com). Leave empty for root domain"
  type        = string
  default     = ""
}

variable "api_subdomain" {
  description = "Subdomain for API (e.g., 'api-dev.btg' for api-dev.btg.puntedge.com)"
  type        = string
  default     = ""
}

variable "create_mfe_record" {
  description = "Create DNS record for MFE CloudFront distribution"
  type        = bool
  default     = true
}

variable "create_api_record" {
  description = "Create DNS record for API Gateway ALB"
  type        = bool
  default     = false
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
  default     = ""
}

variable "cloudfront_zone_id" {
  description = "CloudFront hosted zone ID (always Z2FDTNDATAQYW2 for CloudFront)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

variable "alb_dns_name" {
  description = "ALB DNS name for API routing"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID"
  type        = string
  default     = ""
}
