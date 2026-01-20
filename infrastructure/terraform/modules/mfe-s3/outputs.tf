output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.mfe_bucket.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.mfe_bucket.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.mfe_bucket.bucket_regional_domain_name
}
