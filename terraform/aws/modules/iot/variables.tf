variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "external_id" {
  description = "External ID to register in SORACOM credential store"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.external_id)) >= 2
    error_message = "external_id must contain at least 2 characters."
  }
}
