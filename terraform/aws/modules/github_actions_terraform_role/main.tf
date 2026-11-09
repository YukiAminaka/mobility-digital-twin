# github ActionsでTerraformを実行するためのRoleを作成する

resource "aws_iam_role" "terraform" {
  name               = "${var.project_name}-github-actions-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    sid    = "AllowAssumeRoleWithWebIdentity"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        var.openid_connect_provider_githubactions_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:environment:${var.github_environment}"
      ]
    }
  }
}

# 親ゾーン側Roleへの sts:AssumeRole
data "aws_iam_policy_document" "route53_parent_zone_assume_role" {
  statement {
    sid     = "AssumeRoute53ParentZoneRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    resources = [
      var.route53_parent_zone_role_arn,
    ]
  }
}

resource "aws_iam_role_policy" "route53_parent_zone_assume_role" {
  name   = "${var.project_name}-assume-route53-parent-zone-role"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.route53_parent_zone_assume_role.json
}
