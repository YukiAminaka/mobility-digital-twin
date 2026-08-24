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
  description = "The GitHub repository in the format 'owner/repo' for which the OIDC provider is being created."
}

variable "ecr_repositories_arns" {
  type        = map(string)
  description = "A map of ECR repository ARNs."
}

variable "ecs_service_arns" {
  type        = list(string)
  description = "List of ECS service ARNs that the GitHub Actions role will have access to."
}

variable "ecs_task_execution_role_arn" {
  type        = string
  description = "ARN of the ECS task execution role that the GitHub Actions role is allowed to pass to ECS."
}

variable "ecs_task_role_arn" {
  type        = string
  description = "ARN of the ECS task role that the GitHub Actions role is allowed to pass to ECS."
}