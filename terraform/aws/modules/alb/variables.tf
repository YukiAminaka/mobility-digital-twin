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

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "subdomain_domain_name" {
  type        = string
  description = "Subdomain domain name"
}

variable "subdomain_zone_id" {
  type        = string
  description = "Public hosted zone ID for the velotwin subdomain (used for ACM DNS validation)"
}

variable "private_subdomain_zone_id" {
  type        = string
  description = "Private hosted zone ID for the velotwin subdomain (used for the internal ALB alias record)"
}

variable "bastion_security_group_id" {
  type        = string
  description = "Security group ID of the SSM forwarding host allowed to reach the ALB"
}
