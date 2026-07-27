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

  container_definitions = jsonencode([{
    name      = "websocket"
    image     = "${var.ecr_repositories["websocket"]}:latest"
    essential = true
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

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# ECSタスク実行ロールにAWS管理ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs" {
  for_each = toset(["websocket"])

  name              = "/ecs/${var.project_name}-${var.environment}/${each.key}"
  retention_in_days = 7
}

# プロバイダに設定されているAWSリージョンを取得するためのデータソース
data "aws_region" "current" {}
