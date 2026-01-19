# ==============================================================================
# ECS Cluster & Shared Infrastructure (ALB)
# ==============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

# Public ALB SG (Internet -> Public ALB)
resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-${var.environment}-public-alb-sg"
  description = "Controls access to the Public ALB"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Internal ALB SG (VPC -> Internal ALB)
resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-${var.environment}-internal-alb-sg"
  description = "Controls access to the Internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [var.vpc_cidr] # Allow only VPC traffic
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Tasks SG (Common)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "allow inbound access from ALBs"
  vpc_id      = var.vpc_id

  # Allow traffic from Public ALB
  ingress {
    protocol        = "tcp"
    from_port       = 0 
    to_port         = 65535
    security_groups = [aws_security_group.public_alb.id] 
  }

  # Allow traffic from Internal ALB
  ingress {
    protocol        = "tcp"
    from_port       = 0 
    to_port         = 65535
    security_groups = [aws_security_group.internal_alb.id] 
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# 1. Public Application Load Balancer
# ------------------------------------------------------------------------------
resource "aws_lb" "public" {
  name               = "${var.project_name}-${var.environment}-pub-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb.id]
  subnets            = var.public_subnets

  enable_deletion_protection = var.enable_deletion_protection

  drop_invalid_header_fields = true
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found (Public)"
      status_code  = "404"
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Internal Application Load Balancer
# ------------------------------------------------------------------------------
resource "aws_lb" "internal" {
  name               = "${var.project_name}-${var.environment}-int-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = var.private_subnets

  enable_deletion_protection = var.enable_deletion_protection

  drop_invalid_header_fields = true
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found (Internal)"
      status_code  = "404"
    }
  }
}
