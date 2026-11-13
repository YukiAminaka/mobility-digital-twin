variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
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