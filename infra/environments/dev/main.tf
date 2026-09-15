terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "db_password" {
  description = "The RDS master password"
  type        = string
  sensitive   = true
}

variable "api_image" {
  description = "The published ECS API image URI"
  type        = string
}

provider "aws" {
  region = "us-east-2"
}

locals {
  name = "rhyperior-monitor"
}

# The dev environment assembles all layers of the Earthquake Monitor stack:
# networking, database, ingestion automation, application services, and monitoring.
module "vpc" {
  source     = "../../modules/vpc"
  cidr_block = "10.0.0.0/16"
  name       = local.name
}

module "subnets" {
  source          = "../../modules/subnets"
  vpc_id          = module.vpc.id
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  azs             = ["us-east-2a", "us-east-2b"]
  name            = local.name
}

module "security_groups" {
  source = "../../modules/security_groups"
  vpc_id = module.vpc.id
  name   = local.name
}

module "rds" {
  source          = "../../modules/rds"
  name            = local.name
  private_subnets = module.subnets.private_ids
  sg_id           = module.security_groups.rds_id
  instance_class  = "db.t3.micro"
  db_name         = "rhyperior"
  username        = "admin"
  password        = var.db_password
}

module "lambda_ingestion" {
  source          = "../../modules/lambda_ingestion"
  name            = local.name
  zip_path        = "${path.root}/../../../app/ingestion.zip"
  db_host         = module.rds.host
  db_username     = module.rds.username
  db_password     = module.rds.password
  db_name         = module.rds.db_name
  private_subnets = module.subnets.private_ids
  sg_id           = module.security_groups.lambda_id
}

module "eventbridge" {
  source     = "../../modules/eventbridge"
  name       = local.name
  lambda_arn = module.lambda_ingestion.arn
}

module "alb" {
  source         = "../../modules/alb"
  name           = local.name
  public_subnets = module.subnets.public_ids
  sg_id          = module.security_groups.alb_id
  vpc_id         = module.vpc.id
}

module "ecs" {
  source           = "../../modules/ecs"
  name             = local.name
  image            = var.api_image
  private_subnets  = module.subnets.private_ids
  sg_id            = module.security_groups.ecs_id
  target_group_arn = module.alb.target_group_arn
  db_host          = module.rds.host
  db_username      = module.rds.username
  db_password      = module.rds.password
  db_name          = module.rds.db_name
}

module "monitoring" {
  source                  = "../../modules/monitoring"
  name                    = local.name
  lambda_name             = module.lambda_ingestion.name
  cluster_name            = module.ecs.cluster_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
}
