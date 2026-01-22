# ==============================================================================
# Route 53 DNS Records Module
# ==============================================================================
# Purpose: Manage DNS records for BTG infrastructure
# Uses existing hosted zone created during domain registration
# ==============================================================================

# CloudFront Alias Record (for MFE)
resource "aws_route53_record" "mfe" {
  count   = var.create_mfe_record ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# ALB Alias Record (for API Gateway) - Optional
resource "aws_route53_record" "api" {
  count   = var.create_api_record ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.api_subdomain != "" ? "${var.api_subdomain}.${var.domain_name}" : "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
