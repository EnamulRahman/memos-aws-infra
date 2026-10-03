module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  availability_zones = var.availability_zones
}

module "security" {
  source = "./modules/security"

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
  
}

module "acm" {
  source = "./modules/acm"

  project_name = var.project_name
  domain_name  = var.domain_name
  zone_id      = data.aws_route53_zone.main.zone_id
}

module "alb" {
  source = "./modules/alb"

  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  security_group  = module.security.alb_security_group_id
  certificate_arn = module.acm.certificate_arn
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.repository_name
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
}

module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name

  private_subnet_ids    = module.vpc.private_subnets
  ecs_security_group_id = module.security.ecs_security_group_id

  image_url = var.image_url != "" ? var.image_url : module.ecr.repository_url

  container_port = 8081
  cpu            = 256
  memory         = 512

  desired_count = 1

  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  target_group_arn   = module.alb.target_group_arn
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "tm.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

