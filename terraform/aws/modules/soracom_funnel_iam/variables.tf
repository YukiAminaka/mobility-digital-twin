variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "role_name" {
  description = "IAM Role name for SORACOM Funnel"
  type        = string
}

variable "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN to allow writing to"
  type        = string
}

variable "external_id" {
  description = "External ID to register in SORACOM credential store"
  type        = string
  sensitive   = true
}

variable "soracom_aws_account_id" {
  description = "SORACOM's AWS Account ID"
  type        = string
  default     = "762707677580"
}