output "role_arn" {
  description = "ARN of the IAM role used by GitHub Actions to run Terraform"
  value       = aws_iam_role.terraform.arn
}

output "role_name" {
  description = "Name of the IAM role used by GitHub Actions to run Terraform"
  value       = aws_iam_role.terraform.name
}
