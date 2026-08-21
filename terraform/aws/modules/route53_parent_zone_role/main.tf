# 親ゾーンを管理するAWSアカウントに、GitHub Actions用のロールに
# 親ゾーンへのレコード作成等の操作を許可するIAMロールを作成するモジュール

data "aws_iam_policy_document" "assume_role" {
  provider = aws.route53_parent_zone
  statement {
    sid     = "AllowInfrastructureGitHubActionsRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"

      identifiers = [
        var.infrastructure_github_actions_role_arn,
      ]
    }
  }
}

resource "aws_iam_role" "route53_parent_zone" {
  provider           = aws.route53_parent_zone
  name               = "route53-parent-zone-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "route53_parent_zone_access" {
  provider = aws.route53_parent_zone
  statement {
    sid    = "ManageSubdomainDelegation"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${var.parent_zone_id}",
    ]
  }
}

resource "aws_iam_role_policy" "route53_parent_zone_access" {
  provider = aws.route53_parent_zone
  name     = "route53-parent-zone-access"
  role     = aws_iam_role.route53_parent_zone.id
  policy   = data.aws_iam_policy_document.route53_parent_zone_access.json
}