# github ActionsでTerraformを実行するためのRoleを作成する

resource "aws_iam_role" "terraform" {
  name               = "${var.project_name}-github-actions-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_oidc.json
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
# Terraformで主要リソースを操作する権限
# Terraform state用S3への権限
