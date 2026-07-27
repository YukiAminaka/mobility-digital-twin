output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "websocket_services_sg_id" {
  value = aws_security_group.websocket.id
}
