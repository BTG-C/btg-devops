# ==============================================================================
# SNS Topics Module
# ==============================================================================
# Purpose: Create and manage SNS topics for notifications, alerts, events
# ==============================================================================

# SNS Topic
resource "aws_sns_topic" "main" {
  name              = "${var.project_name}-${var.environment}-${var.topic_name}"
  display_name      = var.display_name
  fifo_topic        = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  # Server-side encryption
  kms_master_key_id = var.enable_encryption ? (var.kms_key_id != "" ? var.kms_key_id : "alias/aws/sns") : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.topic_name}"
    Environment = var.environment
    Purpose     = var.purpose
  }
}

# SNS Topic Policy (optional - for cross-account access)
resource "aws_sns_topic_policy" "main" {
  count  = var.enable_cross_account_access ? 1 : 0
  arn    = aws_sns_topic.main.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublishFromServices"
        Effect = "Allow"
        Principal = {
          Service = var.allowed_services
        }
        Action   = ["SNS:Publish"]
        Resource = aws_sns_topic.main.arn
      }
    ]
  })
}

# Email Subscription (optional)
resource "aws_sns_topic_subscription" "email" {
  count     = length(var.email_subscriptions)
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.email_subscriptions[count.index]
}

# SQS Subscription (optional)
resource "aws_sns_topic_subscription" "sqs" {
  count     = length(var.sqs_subscriptions)
  topic_arn = aws_sns_topic.main.arn
  protocol  = "sqs"
  endpoint  = var.sqs_subscriptions[count.index]
}

# Lambda Subscription (optional)
resource "aws_sns_topic_subscription" "lambda" {
  count     = length(var.lambda_subscriptions)
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_subscriptions[count.index]
}

# HTTP/HTTPS Subscription (optional)
resource "aws_sns_topic_subscription" "http" {
  count     = length(var.http_subscriptions)
  topic_arn = aws_sns_topic.main.arn
  protocol  = var.http_subscriptions[count.index].protocol
  endpoint  = var.http_subscriptions[count.index].endpoint
}
