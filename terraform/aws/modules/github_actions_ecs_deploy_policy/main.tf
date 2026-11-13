data "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-githubactions-role"
}

resource "aws_iam_policy" "github_actions_ecs_deploy" {
  name   = "${var.project_name}-${var.environment}-github-actions-ecs-deploy-policy"
  policy = data.aws_iam_policy_document.github_actions_ecs_deploy.json
}

data "aws_iam_policy_document" "github_actions_ecs_deploy" {
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

resource "aws_iam_role_policy_attachment" "github_actions_ecs_deploy" {
  role       = data.aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecs_deploy.arn
}