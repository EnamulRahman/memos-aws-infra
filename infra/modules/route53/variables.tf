variable "zone_id" {
  description = "Public hosted zone ID"
  type        = string
}

variable "record_name" {
  description = "Website DNS name"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB canonical hosted zone ID"
  type        = string
}