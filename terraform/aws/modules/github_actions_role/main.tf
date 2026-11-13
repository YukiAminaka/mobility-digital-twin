# ============================================================
# IAM Role for GitHub Actions
# ============================================================

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-${var.environment}-githubactions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json

  tags = {
    Name    = "${var.project_name}-${var.environment}-githubactions-role"
    Project = var.project_name
  }
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
        "repo:${var.github_repository}:environment:${var.environment}"
      ]
    }
  }
}

resource "aws_iam_policy" "github_actions_ecr_push" {
  name   = "${var.project_name}-${var.environment}-github-actions-ecr-push-policy"
  policy = data.aws_iam_policy_document.github_actions_ecr_push.json
}

data "aws_iam_policy_document" "github_actions_ecr_push" {
  statement {
    sid = "ECRAuthorization"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      for repo_arn in var.ecr_repositories_arns : repo_arn
    ]
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}