# ==============================================================================
# Reusable ECS Service Module
# ==============================================================================

# 1. CloudWatch Logs
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.project_name}-${var.environment}-${var.service_name}"
  retention_in_days = 7
}

# 2. Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  
  # Use least outstanding requests for better load distribution
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200,301,302"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }
}

# 3. Listener Rule
resource "aws_lb_listener_rule" "main" {
  listener_arn = var.listener_arn
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern] 
    }
  }
}

# 4. IAM Roles (Managed Externally)
# Note: IAM roles are created in the centralized 'modules/iam' and passed via variables
# This module only uses the role ARNs for task definition

# 5. Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.environment}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = var.environment_variables
      secrets     = var.secrets
    }
  ])
}

# 6. ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.security_group_id]
    subnets          = var.private_subnets
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.main]
  
  # Ignore desired_count changes when auto-scaling is enabled
  lifecycle {
    ignore_changes = var.enable_autoscaling ? [desired_count] : []
  }
}

# ==============================================================================
# Auto-Scaling Configuration
# ==============================================================================

# 8. Application Auto-Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${split("/", var.cluster_id)[1]}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 9. CPU-Based Auto-Scaling Policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 300  # 5 minutes cooldown before scaling in
    scale_out_cooldown = 60   # 1 minute cooldown before scaling out
  }
}

# 10. Memory-Based Auto-Scaling Policy
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = 300  # 5 minutes cooldown before scaling in
    scale_out_cooldown = 60   # 1 minute cooldown before scaling out
  }
}
