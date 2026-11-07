output "role_arn" {
  description = "ARN of the IAM role created for SORACOM Funnel"
  value       = aws_iam_role.soracom_funnel.arn
}

output "role_name" {
  description = "Name of the IAM role created for SORACOM Funnel"
  value       = aws_iam_role.soracom_funnel.name
}