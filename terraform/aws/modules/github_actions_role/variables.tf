variable "project_name" {
  type        = string
  description = "Project name"
}

variable "openid_connect_provider_githubactions_arn" {
  type        = string
  description = "ARN of the OpenID Connect provider for GitHub Actions"
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository in the format 'owner/repo' allowed to assume the role."
}

variable "environment" {
  type        = string
  description = "Environment name. Also used as the GitHub Actions environment name allowed to assume the role."
}

variable "ecr_repositories_arns" {
  type        = map(string)
  description = "A map of ECR repository ARNs."
}
