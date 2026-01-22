# ==============================================================================
# ACM Certificate Module
# ==============================================================================
# Purpose: Request and validate SSL/TLS certificates for CloudFront and ALB
# IMPORTANT: Certificates for CloudFront MUST be in us-east-1 region
# ==============================================================================

# Validation: Ensure we're using correct region (us-east-1 for CloudFront, any for ALB)
data "aws_region" "current" {}

locals {
  is_valid_region = data.aws_region.current.name == var.required_region
}

# ACM Certificate Request
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cert"
    Environment = var.environment
    Region      = data.aws_region.current.name
  }

  lifecycle {
    create_before_destroy = true
    
    precondition {
      condition     = local.is_valid_region
      error_message = "ACM certificate must be created in ${var.required_region} region. Current region: ${data.aws_region.current.name}"
    }
  }
}

# Route 53 DNS Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "45m"  # DNS propagation can take 20-30 minutes
  }
}
