output "name" {
  description = "Name of the Kinesis data stream"
  value       = aws_kinesis_stream.device_data.name
}

output "arn" {
  description = "ARN of the Kinesis data stream"
  value       = aws_kinesis_stream.device_data.arn
}
