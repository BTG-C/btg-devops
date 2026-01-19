output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "public_listener_arn" {
  description = "Public ALB HTTP listener ARN (for services when no SSL)"
  value       = aws_lb_listener.public_http.arn
}

output "public_https_listener_arn" {
  description = "Public ALB HTTPS listener ARN (for services with SSL certificate)"
  value       = var.ssl_certificate_arn != "" ? aws_lb_listener.public_https[0].arn : ""
}

output "internal_listener_arn" {
  value = aws_lb_listener.internal_http.arn
}

output "ecs_tasks_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "public_alb_dns" {
  value = aws_lb.public.dns_name
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}

output "ecs_tasks_sg_id" {
  value = aws_security_group.ecs_tasks.id
}
