variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "velotwin"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "ami-works.com"
}

variable "subdomain_domain_name" {
  description = "Subdomain domain name"
  type        = string
  default     = "velotwin.ami-works.com"
}

variable "websocket_image_tag" {
  description = "Immutable ECR image tag for the WebSocket application"
  type        = string

  validation {
    condition = (
      length(trimspace(var.websocket_image_tag)) > 0 &&
      lower(trimspace(var.websocket_image_tag)) != "latest"
    )
    error_message = "websocket_image_tag must be a non-empty immutable tag and must not be 'latest'."
  }
}

variable "soracom_external_id" {
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
