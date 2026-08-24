# ============================================================
# IAM Role for GitHub Actions
# ============================================================

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-githubactions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json

  tags = {
    Name    = "${var.project_name}-githubactions-role"
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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:*"
      ]
    }
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name   = "${var.project_name}-github-actions-deploy-policy"
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

data "aws_iam_policy_document" "github_actions_deploy" {
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

  statement {
    sid = "DescribeTaskDefinition"
    actions = [
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RegisterTaskDefinition"
    actions = [
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "UpdateService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [
      for service_arn in var.ecs_service_arns : service_arn
    ]
  }

  statement {
    sid    = "PassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      var.ecs_task_execution_role_arn,
      var.ecs_task_role_arn,
    ]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}