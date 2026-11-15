locals {
  topic_prefix           = "bicycle/telemetry"
  soracom_aws_account_id = "762707677580"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# SORACOM の AWS アカウントを信頼できるエンティティとして指定したIAMロールを作成
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
        "arn:aws:iam::${local.soracom_aws_account_id}:root"
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


resource "aws_iam_role" "soracom_funnel_aws_iot" {
  name = "${var.project_name}-${var.environment}-soracom-funnel-aws-iot-role"

  assume_role_policy = sensitive(data.aws_iam_policy_document.soracom_funnel_assume_role.json)
}


data "aws_iam_policy_document" "publish" {
  statement {
    sid    = "AllowPublish"
    effect = "Allow"
    actions = [
      "iot:Publish"
    ]
    resources = [
      "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${local.topic_prefix}/*"
    ]
  }
}

# 特定のトピックへのpublishを許可するポリシー
resource "aws_iam_policy" "publish" {
  name   = "${var.project_name}-${var.environment}-iot-publish"
  policy = data.aws_iam_policy_document.publish.json
}

resource "aws_iam_role_policy_attachment" "soracom_funnel_aws_iot_role_publish" {
  role       = aws_iam_role.soracom_funnel_aws_iot.name
  policy_arn = aws_iam_policy.publish.arn
}

# AWS IoT Core のドメイン設定
resource "aws_iot_domain_configuration" "funnel" {
  name         = "${var.project_name}-${var.environment}-soracom-funnel-aws-iot-domain"
  service_type = "DATA"
  status       = "ENABLED"
}
