# ============================================================
# ECS
# ============================================================
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# タスク定義
resource "aws_ecs_task_definition" "websocket" {
  family                   = "${var.project_name}-${var.environment}-websocket"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.websocket_task.arn

  container_definitions = jsonencode([{
    name      = "websocket"
    image     = "${var.ecr_repositories["websocket"]}:${var.websocket_image_tag}"
    essential = true
    environment = [
      {
        name  = "KINESIS_STREAM_NAME"
        value = var.kinesis_stream_name
      }
    ]
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs["websocket"].name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# サービス
resource "aws_ecs_service" "websocket" {
  name            = "${var.project_name}-${var.environment}-websocket"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.websocket.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.websocket.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arns["websocket"]
    container_name   = "websocket"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }
}

# Security Groups
resource "aws_security_group" "websocket" {
  name        = "${var.project_name}-${var.environment}-websocket-sg"
  description = "Security group for WebSocket ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-websocket-sg"
  }
}

# ALBからWebSocketサービスへのトラフィックを許可するIngressルール
resource "aws_vpc_security_group_ingress_rule" "websocket_from_alb" {
  security_group_id            = aws_security_group.websocket.id
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from ALB"
}

# ECSタスクからECR/CloudWatch Logs/Secrets Manager/Kinesis Data Streams へのアウトバウンドトラフィックを許可するEgressルール
# trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "websocket_https" {
  security_group_id = aws_security_group.websocket.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS for AWS APIs and external services"
}

# ECSタスク実行ロール
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution"

  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_task_execution_role.json
}

data "aws_iam_policy_document" "trust_policy_for_task_execution_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ECSタスク実行ロールにAWS管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# WebSocketアプリケーション用のECSタスクロール
resource "aws_iam_role" "websocket_task" {
  name = "${var.project_name}-${var.environment}-websocket-task"

  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_websocket_task_role.json
}

data "aws_iam_policy_document" "trust_policy_for_websocket_task_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "kinesis_read" {
  statement {
    sid    = "AllowReadFromKinesis"
    effect = "Allow"

    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
    ]

    resources = [var.kinesis_stream_arn]
  }
}

resource "aws_iam_policy" "kinesis_read" {
  name   = "${var.project_name}-${var.environment}-kinesis-read"
  policy = data.aws_iam_policy_document.kinesis_read.json
}

resource "aws_iam_role_policy_attachment" "kinesis_read" {
  role       = aws_iam_role.websocket_task.name
  policy_arn = aws_iam_policy.kinesis_read.arn
}

# ============================================================
# CloudWatch Logs
# ============================================================

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs" {
  for_each = toset(["websocket"])

  name              = "/ecs/${var.project_name}-${var.environment}/${each.key}"
  retention_in_days = 7
}

# プロバイダに設定されているAWSリージョンを取得するためのデータソース
data "aws_region" "current" {}
