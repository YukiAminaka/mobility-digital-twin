variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN to allow writing to"
  type        = string
}

variable "external_id" {
  description = "External ID to register in SORACOM credential store"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.soracom_external_id)) >= 2
    error_message = "soracom_external_id must contain at least 2 characters."
  }
}

variable "soracom_aws_account_id" {
  description = "SORACOM's AWS Account ID"
  type        = string
  default     = "762707677580"

  validation {
    condition = contains([
      "762707677580",
      "950858143650",
    ], var.soracom_aws_account_id)
    error_message = "soracom_aws_account_id must be the account ID for JP or Global coverage."
  }
}