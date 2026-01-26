output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.main.arn
}

output "topic_id" {
  description = "ID of the SNS topic"
  value       = aws_sns_topic.main.id
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.main.name
}
