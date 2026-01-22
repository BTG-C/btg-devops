# ==============================================================================
# Route 53 Module Outputs
# ==============================================================================

output "mfe_fqdn" {
  description = "Fully qualified domain name for MFE"
  value       = var.create_mfe_record ? aws_route53_record.mfe[0].fqdn : ""
}

output "api_fqdn" {
  description = "Fully qualified domain name for API"
  value       = var.create_api_record ? aws_route53_record.api[0].fqdn : ""
}
