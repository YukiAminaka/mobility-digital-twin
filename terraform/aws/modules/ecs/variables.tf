variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_target_group_arns" {
  type        = map(string)
  description = "ALB target group ARNs (websocket only)"
}

variable "alb_security_group_id" {
  type = string
}

variable "ecr_repositories" {
  type = map(string)
}

variable "websocket_image_tag" {
  description = "Immutable image tag for the WebSocket application"
  type        = string

  validation {
    condition = (
      length(trimspace(var.websocket_image_tag)) > 0 &&
      lower(trimspace(var.websocket_image_tag)) != "latest"
    )
    error_message = "websocket_image_tag must be a non-empty immutable tag and must not be 'latest'."
  }
}

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis data stream consumed by the application"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Name of the Kinesis data stream consumed by the application"
  type        = string
}
