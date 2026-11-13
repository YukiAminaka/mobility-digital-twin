variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Private subnet in which to place the SSM forwarding host"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the SSM forwarding host"
  type        = string
  default     = "t4g.nano"
}
