# ============================================================
# SSM Session Manager forwarding host
# ------------------------------------------------------------
# 公開ALBを経由せず、developer端末からSSM Session Manager
# (AWS-StartPortForwardingSessionToRemoteHost) 経由でVPC内の
# ALB/ECSタスクへポートフォワードするための踏み台。
# ・SSHポートは一切開放しない（Ingressルールなし）
# ・パブリックIPを持たない
# ============================================================

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------
# Security Group
# ------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-ssm-bastion-sg"
  description = "Security group for the SSM Session Manager forwarding host"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-ssm-bastion-sg"
  }
}

# SSMエンドポイント(NAT経由)およびVPC内リソースへのHTTPSアウトバウンドを許可
# Ingressルールは定義しない(SSM Agentはアウトバウンド接続のみで動作するため)
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.this.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS to SSM endpoints and VPC resources (e.g. ALB)"
}

# ------------------------------------------------------------
# IAM Role / Instance Profile
# ------------------------------------------------------------
data "aws_iam_policy_document" "trust_policy_for_ec2" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name = "${var.project_name}-${var.environment}-ssm-bastion"

  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.environment}-ssm-bastion"
  role = aws_iam_role.this.name
}

# ------------------------------------------------------------
# EC2 Instance
# ------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ssm-bastion"
  }
}

# ------------------------------------------------------------
# Developer向け IAM Policy (ssm:StartSession)
# ------------------------------------------------------------
data "aws_iam_policy_document" "developer_start_session" {
  statement {
    sid    = "AllowStartSessionToBastion"
    effect = "Allow"

    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.this.id}",
      "arn:aws:ssm:${data.aws_region.current.region}::document/AWS-StartPortForwardingSessionToRemoteHost",
    ]
  }

  statement {
    sid    = "AllowManageOwnSessions"
    effect = "Allow"

    actions = [
      "ssm:TerminateSession",
      "ssm:ResumeSession",
    ]

    resources = ["arn:aws:ssm:*:*:session/$${aws:username}-*"]
  }

  statement {
    sid    = "AllowDescribeSessions"
    effect = "Allow"

    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "developer_start_session" {
  name   = "${var.project_name}-${var.environment}-ssm-bastion-start-session"
  policy = data.aws_iam_policy_document.developer_start_session.json
}

resource "aws_iam_user_policy_attachment" "developer_start_session" {
  for_each = toset(var.developer_iam_user_names)

  user       = each.value
  policy_arn = aws_iam_policy.developer_start_session.arn
}
