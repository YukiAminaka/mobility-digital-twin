output "role_arn" {
  description = "ARN of the role used to manage the parent Route 53 hosted zone"
  value       = aws_iam_role.route53_parent_zone.arn
}