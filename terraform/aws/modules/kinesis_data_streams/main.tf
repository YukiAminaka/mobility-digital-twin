resource "aws_kinesis_stream" "device_data" {
  name             = "${var.project_name}-${var.environment}-device-data"
  retention_period = var.retention_period
  shard_count      = var.stream_mode == "PROVISIONED" ? var.shard_count : null

  stream_mode_details {
    stream_mode = var.stream_mode
  }

  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"

  tags = {
    Name        = "${var.project_name}-${var.environment}-device-data"
    Project     = var.project_name
    Environment = var.environment
  }
}