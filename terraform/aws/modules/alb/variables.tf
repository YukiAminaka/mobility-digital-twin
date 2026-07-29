variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the ALB will be deployed"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "subdomain_domain_name" {
  type        = string
  description = "Subdomain domain name"
}

variable "subdomain_zone_id" {
  type        = string
  description = "Hosted zone ID for the velotwin subdomain"
}
