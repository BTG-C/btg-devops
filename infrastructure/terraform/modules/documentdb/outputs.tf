output "endpoint" {
  description = "The endpoint of the DocumentDB cluster"
  value       = aws_docdb_cluster.main.endpoint
}

output "cluster_endpoint" {
  description = "The endpoint of the DocumentDB cluster (alias)"
  value       = aws_docdb_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "The reader endpoint of the DocumentDB cluster"
  value       = aws_docdb_cluster.main.reader_endpoint
}

output "cluster_resource_id" {
  description = "The resource ID of the DocumentDB cluster"
  value       = aws_docdb_cluster.main.cluster_resource_id
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.docdb.id
}

output "master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.docdb_credentials.arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials (alias)"
  value       = aws_secretsmanager_secret.docdb_credentials.arn
}
