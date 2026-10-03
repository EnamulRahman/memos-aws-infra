resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
  })
}

# Public HTTP is required to redirect visitors to HTTPS.
# tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTP for HTTPS redirect"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Public HTTPS is required for visitors to access Memos.
# tfsec:ignore:aws-ec2-no-public-ingress-sgr
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow Memos traffic and health checks"
  ip_protocol                  = "tcp"
  from_port                    = 8081
  to_port                      = 8081
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow Memos traffic from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 8081
  to_port                      = 8081
}

# HTTPS via NAT supports ECR, S3 image layers and CloudWatch.
# Accepted limitation: any destination is allowed on TCP 443.
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow outbound HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}