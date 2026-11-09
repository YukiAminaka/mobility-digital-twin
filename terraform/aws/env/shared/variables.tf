variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format allowed to assume the GitHub Actions role"
  type        = string
  default     = "YukiAminaka/mobility-digital-twin"
}

