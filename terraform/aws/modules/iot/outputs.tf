output "role_arn" {
  description = "ARN of the IAM role assumed by SORACOM Funnel to publish to AWS IoT Core"
  value       = aws_iam_role.soracom_funnel_aws_iot.arn
}
