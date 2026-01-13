# ==============================================================================
# SSM PARAMETERS FOR BLUE-GREEN DEPLOYMENT
# ==============================================================================

resource "aws_ssm_parameter" "active_environment" {
  count = local.enable_blue_green ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/active-env"
  type  = "String"
  value = "blue"  # Default to blue environment

  tags = merge(local.common_tags, {
    Description = "Tracks the currently active environment for blue-green deployment"
  })
}