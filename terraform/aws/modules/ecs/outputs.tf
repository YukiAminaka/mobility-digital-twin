output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "websocket_service_arn" {
  value = aws_ecs_service.websocket.arn
}

output "websocket_services_sg_id" {
  value = aws_security_group.websocket.id
}

output "task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.websocket_task.arn
}
