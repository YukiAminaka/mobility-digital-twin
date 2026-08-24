variable "domain_name" {
  type        = string
  description = "Domain name for the Route53 zone"
}

variable "subdomain_domain_name" {
  type        = string
  description = "Subdomain domain name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to associate with the private hosted zone for the subdomain"
}
