output "arn" {
  description = "ARN of the IAM OIDC provider created for GitHub Actions"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}