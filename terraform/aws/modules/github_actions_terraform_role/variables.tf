variable "project_name" {
  type        = string
  description = "Project name"
}

variable "route53_parent_zone_role_arn" {
  description = "ARN of the role used to manage the parent Route 53 hosted zone"
  type        = string
}

variable "openid_connect_provider_githubactions_arn" {
  type        = string
  description = "ARN of the OpenID Connect provider for GitHub Actions"
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository in the format 'owner/repo' allowed to assume the role."
}

variable "github_environment" {
  type        = string
  description = "The GitHub Actions environment name allowed to assume the role."
}
