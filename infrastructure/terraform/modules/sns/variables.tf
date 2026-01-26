variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "topic_name" {
  description = "Name of the SNS topic (will be prefixed with project-environment)"
  type        = string
}

variable "display_name" {
  description = "Display name for the SNS topic"
  type        = string
  default     = ""
}

variable "purpose" {
  description = "Purpose/description of the SNS topic"
  type        = string
  default     = "Notifications"
}

variable "fifo_topic" {
  description = "Whether to create a FIFO topic (ordered messages)"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication for FIFO topics"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption for the topic"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (uses AWS managed key if empty)"
  type        = string
  default     = ""
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access via topic policy"
  type        = bool
  default     = false
}

variable "allowed_services" {
  description = "List of AWS services allowed to publish (e.g., lambda.amazonaws.com)"
  type        = list(string)
  default     = []
}

variable "email_subscriptions" {
  description = "List of email addresses to subscribe to the topic"
  type        = list(string)
  default     = []
}

variable "sqs_subscriptions" {
  description = "List of SQS queue ARNs to subscribe to the topic"
  type        = list(string)
  default     = []
}

variable "lambda_subscriptions" {
  description = "List of Lambda function ARNs to subscribe to the topic"
  type        = list(string)
  default     = []
}

variable "http_subscriptions" {
  description = "List of HTTP/HTTPS endpoints to subscribe"
  type = list(object({
    protocol = string
    endpoint = string
  }))
  default = []
}
