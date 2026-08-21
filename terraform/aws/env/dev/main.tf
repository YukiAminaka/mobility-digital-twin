terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.50"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-mobility-digital-twin-dev"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.infrastructure_aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias   = "route53_parent_zone"
  region  = var.aws_region
  profile = var.route53_parent_zone_aws_profile
}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "route53" {
  source                = "../../modules/route53"
  domain_name           = var.domain_name
  subdomain_domain_name = var.subdomain_domain_name

  providers = {
    aws                     = aws
    aws.route53_parent_zone = aws.route53_parent_zone
  }
}

module "alb" {
  source                = "../../modules/alb"
  subdomain_domain_name = var.subdomain_domain_name
  subdomain_zone_id     = module.route53.subdomain_zone_id
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  repositories = ["websocket"]
}

module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_target_group_arns = module.alb.target_group_arns
  alb_security_group_id = module.alb.alb_security_group_id
  ecr_repositories      = module.ecr.repository_urls
  websocket_image_tag   = var.websocket_image_tag
  kinesis_stream_arn    = module.kinesis_device_data.arn
  kinesis_stream_name   = module.kinesis_device_data.name

  depends_on = [module.alb]
}

module "kinesis_device_data" {
  project_name = var.project_name
  environment  = var.environment
  source       = "../../modules/kinesis_data_streams"

  retention_period = 24
  stream_mode      = "ON_DEMAND"
}

module "openid_connect_provider" {
  source = "../../modules/openid_connect_provider"

  project_name = var.project_name
}

module "github_actions_role" {
  source = "../../modules/github_actions_role"

  project_name                = var.project_name
  openid_connect_provider_githubactions_arn = module.openid_connect_provider.arn
  github_repository           = var.github_repository
  ecr_repositories_arns       = module.ecr.repository_arns
  ecs_service_arns            = [module.ecs.websocket_service_arn]
  ecs_task_execution_role_arn = module.ecs.task_execution_role_arn
  ecs_task_role_arn           = module.ecs.task_role_arn
}

module "soracom_funnel_iam" {
  project_name = var.project_name
  environment  = var.environment
  source       = "../../modules/soracom_funnel_iam"

  kinesis_stream_arn     = module.kinesis_device_data.arn
  external_id            = var.soracom_external_id
  soracom_aws_account_id = var.soracom_aws_account_id
}

# ============================================================
# Security Group
# ============================================================

# albのセキュリティグループからWebSocketサービスへのトラフィックを許可するEgressルール
resource "aws_vpc_security_group_egress_rule" "alb_to_websocket" {
  security_group_id            = module.alb.alb_security_group_id
  referenced_security_group_id = module.ecs.websocket_services_sg_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to WebSocket service"
}
