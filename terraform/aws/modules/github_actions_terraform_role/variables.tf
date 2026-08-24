variable "project_name" {
  type        = string
  description = "Project name"
}

variable "route53_parent_zone_role_arn" {
  description = "ARN of the role used to manage the parent Route 53 hosted zone"
  type        = string
}
