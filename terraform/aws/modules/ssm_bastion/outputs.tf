output "instance_id" {
  description = "Instance ID of the SSM forwarding host"
  value       = aws_instance.this.id
}

output "security_group_id" {
  description = "Security group ID of the SSM forwarding host"
  value       = aws_security_group.this.id
}

output "developer_iam_policy_arn" {
  description = "ARN of the IAM policy granting permission to start SSM sessions through the forwarding host"
  value       = aws_iam_policy.developer_start_session.arn
}

output "start_port_forward_command_example" {
  description = "Example AWS CLI command to forward a local port to the ALB through this bastion"
  value       = "aws ssm start-session --target ${aws_instance.this.id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"<ALB_DNS_NAME>\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"8443\"]}'"
}
