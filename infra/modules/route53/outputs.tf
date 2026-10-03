module "route53" {
  source = "./modules/route53"

  zone_id      = data.aws_route53_zone.main.zone_id
  record_name  = "tm.${var.domain_name}"
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.alb_zone_id
}