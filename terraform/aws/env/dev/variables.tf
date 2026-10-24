variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "infrastructure_aws_profile" {
  description = "AWS CLI profile for the account in which the primary infrastructure, including the delegated subdomain hosted zone, is managed"
  type        = string
}

variable "route53_parent_zone_aws_profile" {
  description = "AWS CLI profile for the account that manages the parent Route 53 hosted zone and its subdomain delegation NS record"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
}

variable "subdomain_domain_name" {
  description = "Subdomain domain name"
  type        = string
}

variable "websocket_image_tag" {
  description = "Immutable ECR image tag for the WebSocket application"
  type        = string
}

variable "soracom_external_id" {
  description = "External ID to register in SORACOM credential store"
  type        = string
  sensitive   = true
}

variable "soracom_aws_account_id" {
  description = "SORACOM's AWS Account ID"
  type        = string
  default     = "762707677580"
}

variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format allowed to assume the GitHub Actions role"
  type        = string
  default     = "YukiAminaka/mobility-digital-twin"
}

variable "ssm_bastion_developer_iam_user_names" {
  description = "IAM user names granted permission to start SSM sessions through the SSM forwarding host"
  type        = list(string)
  default     = []
}
