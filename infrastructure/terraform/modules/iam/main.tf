# ==============================================================================
# Centralized IAM Module
# ==============================================================================
# Purpose: Manage all IAM roles, policies, and permissions for BTG infrastructure
# Scope: ECS roles, GitHub Actions OIDC, Lambda roles (future), cross-account roles
# ==============================================================================

# ==============================================================================
# ECS TASK EXECUTION ROLES
# ==============================================================================
# Purpose: Infrastructure-level permissions (pull images, write logs, read secrets)
# Used by: ECS Fargate to manage task lifecycle
# ==============================================================================

resource "aws_iam_role" "ecs_task_execution" {
  for_each = var.ecs_services
  
  name = "${var.project_name}-${var.environment}-${each.key}-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-execution-role"
    Environment = var.environment
    Service     = each.key
    Purpose     = "ECS Task Execution"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  for_each = var.ecs_services
  
  role       = aws_iam_role.ecs_task_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager & SSM Parameter Store access for task execution
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  for_each = var.ecs_services
  
  name = "${var.project_name}-${var.environment}-${each.key}-secrets-access"
  role = aws_iam_role.ecs_task_execution[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameters",
        "ssm:GetParameter"
      ]
      Resource = [
        "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/${var.environment}/*",
        "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      ]
    }]
  })
}

# ==============================================================================
# ECS TASK ROLES (Application-Level Permissions)
# ==============================================================================
# Purpose: Permissions for application code to call AWS services
# Used by: Application SDK calls (SNS, S3, DynamoDB, etc.)
# ==============================================================================

resource "aws_iam_role" "ecs_task" {
  for_each = {
    for k, v in var.ecs_services : k => v
    if v.enable_task_role
  }
  
  name = "${var.project_name}-${var.environment}-${each.key}-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-task-role"
    Environment = var.environment
    Service     = each.key
    Purpose     = "ECS Task Application Permissions"
  }
}

# ==============================================================================
# SNS PERMISSIONS
# ==============================================================================

resource "aws_iam_role_policy" "ecs_task_sns" {
  for_each = {
    for k, v in var.ecs_services : k => v
    if v.enable_task_role && v.enable_sns
  }
  
  name = "${var.project_name}-${var.environment}-${each.key}-sns-policy"
  role = aws_iam_role.ecs_task[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SNSPublishAccess"
      Effect   = "Allow"
      Action   = each.value.sns_actions
      Resource = each.value.sns_topic_arns
    }]
  })
}

# ==============================================================================
# S3 PERMISSIONS (Future - Placeholder)
# ==============================================================================

resource "aws_iam_role_policy" "ecs_task_s3" {
  for_each = {
    for k, v in var.ecs_services : k => v
    if v.enable_task_role && v.enable_s3
  }
  
  name = "${var.project_name}-${var.environment}-${each.key}-s3-policy"
  role = aws_iam_role.ecs_task[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3Access"
      Effect = "Allow"
      Action = each.value.s3_actions
      Resource = each.value.s3_bucket_arns
    }]
  })
}

# ==============================================================================
# DYNAMODB PERMISSIONS (Future - Placeholder)
# ==============================================================================

resource "aws_iam_role_policy" "ecs_task_dynamodb" {
  for_each = {
    for k, v in var.ecs_services : k => v
    if v.enable_task_role && v.enable_dynamodb
  }
  
  name = "${var.project_name}-${var.environment}-${each.key}-dynamodb-policy"
  role = aws_iam_role.ecs_task[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DynamoDBAccess"
      Effect = "Allow"
      Action = each.value.dynamodb_actions
      Resource = each.value.dynamodb_table_arns
    }]
  })
}

# ==============================================================================
# GITHUB ACTIONS OIDC ROLE
# ==============================================================================
# Purpose: Passwordless deployment from GitHub Actions to AWS
# Security: Uses OIDC federation, no long-lived credentials
# ==============================================================================

# Check if GitHub OIDC provider exists
data "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_actions ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

# GitHub Actions Role for MFE Deployment
resource "aws_iam_role" "github_actions_mfe" {
  count = var.enable_github_actions ? 1 : 0
  name  = "${var.project_name}-${var.environment}-github-actions-mfe"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions-mfe"
    Environment = var.environment
    Purpose     = "GitHub Actions MFE Deployment"
  }
}

# GitHub Actions S3 and CloudFront permissions
resource "aws_iam_role_policy" "github_actions_mfe_policy" {
  count = var.enable_github_actions ? 1 : 0
  name  = "mfe-deployment-policy"
  role  = aws_iam_role.github_actions_mfe[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3MFEAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = concat(
          [var.mfe_s3_bucket_arn],
          ["${var.mfe_s3_bucket_arn}/*"]
        )
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution"
        ]
        Resource = var.mfe_cloudfront_distribution_arn
      },
      {
        Sid    = "CloudFrontList"
        Effect = "Allow"
        Action = ["cloudfront:ListDistributions"]
        Resource = "*"
      }
    ]
  })
}
