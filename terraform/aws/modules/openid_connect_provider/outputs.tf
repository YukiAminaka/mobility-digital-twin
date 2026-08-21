output "arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}