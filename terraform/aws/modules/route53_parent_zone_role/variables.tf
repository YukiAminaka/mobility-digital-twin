variable "infrastructure_github_actions_role_arn" {
  description = "ARN of the GitHub Actions role in the infrastructure account"
  type        = string
}

variable "parent_zone_id" {
  description = "Hosted zone ID of the parent Route 53 zone"
  type        = string
}