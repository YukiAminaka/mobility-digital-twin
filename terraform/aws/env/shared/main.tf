terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.50"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-mobility-digital-twin-shared"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# 同じURLのIAM OIDCプロバイダーはAWSアカウントごとに一つ作成し、複数のIAM Roleから信頼先として利用する
module "openid_connect_provider" {
  source = "../../modules/openid_connect_provider"

  project_name = var.project_name
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  repositories = ["websocket"]
}

module "github_actions_dev_role" {
  source = "../../modules/github_actions_role"

  project_name                              = var.project_name
  openid_connect_provider_githubactions_arn = module.openid_connect_provider.arn
  github_repository                         = var.github_repository
  environment                               = "dev"
  ecr_repositories_arns                     = module.ecr.repository_arns
}
