# ==============================================================================
# ECS Task Execution Role Outputs
# ==============================================================================

output "ecs_task_execution_role_arns" {
  description = "Map of service names to task execution role ARNs"
  value = {
    for k, v in aws_iam_role.ecs_task_execution : k => v.arn
  }
}

output "ecs_task_execution_role_names" {
  description = "Map of service names to task execution role names"
  value = {
    for k, v in aws_iam_role.ecs_task_execution : k => v.name
  }
}

# ==============================================================================
# ECS Task Role Outputs
# ==============================================================================

output "ecs_task_role_arns" {
  description = "Map of service names to task role ARNs (only for services with task roles)"
  value = {
    for k, v in aws_iam_role.ecs_task : k => v.arn
  }
}

output "ecs_task_role_names" {
  description = "Map of service names to task role names (only for services with task roles)"
  value = {
    for k, v in aws_iam_role.ecs_task : k => v.name
  }
}

# ==============================================================================
# GitHub Actions OIDC Outputs
# ==============================================================================

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role for MFE deployment"
  value       = var.enable_github_actions ? aws_iam_role.github_actions_mfe[0].arn : null
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions OIDC role"
  value       = var.enable_github_actions ? aws_iam_role.github_actions_mfe[0].name : null
}

# ==============================================================================
# Summary Output (for debugging)
# ==============================================================================

output "iam_summary" {
  description = "Summary of all IAM roles created"
  value = {
    ecs_execution_roles = keys(aws_iam_role.ecs_task_execution)
    ecs_task_roles      = keys(aws_iam_role.ecs_task)
    github_actions_enabled = var.enable_github_actions
  }
}
