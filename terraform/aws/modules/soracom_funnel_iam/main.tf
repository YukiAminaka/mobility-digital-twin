data "aws_iam_policy_document" "soracom_funnel_assume_role" {
  statement {
    sid    = "AllowSoracomFunnelAssumeRole"
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${var.soracom_aws_account_id}:root"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"

      values = [
        var.external_id
      ]
    }
  }
}

resource "aws_iam_role" "soracom_funnel" {
  name = "${var.project_name}-${var.environment}-soracom-funnel-role"

  assume_role_policy = sensitive(data.aws_iam_policy_document.soracom_funnel_assume_role.json)

  tags = {
    Name        = "${var.project_name}-${var.environment}-soracom-funnel-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# kinesisへの書き込みを許可するポリシーjson
data "aws_iam_policy_document" "kinesis_write" {
  statement {
    sid    = "AllowWriteToKinesis"
    effect = "Allow"

    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]

    resources = [
      var.kinesis_stream_arn
    ]
  }
}

# kinesisへの書き込みを許可するポリシー
resource "aws_iam_policy" "kinesis_write" {
  name   = "${var.project_name}-${var.environment}-kinesis-write"
  policy = data.aws_iam_policy_document.kinesis_write.json
}

# kinesisへの書き込みを許可するポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "kinesis_write" {
  role       = aws_iam_role.soracom_funnel.name
  policy_arn = aws_iam_policy.kinesis_write.arn
}
