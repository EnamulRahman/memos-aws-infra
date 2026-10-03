resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["tm.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name = "${var.project_name}-certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for option in aws_acm_certificate.this.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for record in aws_route53_record.validation : record.fqdn
  ]
}

variable "zone_id" {
  description = "Route53 hosted zone ID used for ACM DNS validation records"
  type        = string
}