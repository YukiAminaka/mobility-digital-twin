variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "stream_mode" {
  description = "Specifies the capacity mode of the stream. Must be either PROVISIONED or ON_DEMAND."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition = contains(
      ["ON_DEMAND", "PROVISIONED"],
      var.stream_mode
    )

    error_message = "stream_mode must be either 'ON_DEMAND' or 'PROVISIONED'."
  }
}

variable "shard_count" {
  description = "The number of shards that the stream uses. Required if stream_mode is PROVISIONED."
  type        = number
  default     = 1
}