resource "aws_lb" "this" {
  name = "${var.project_name}-alb"

  # Public access is required for visitors to reach Memos.
  internal = false # tfsec:ignore:aws-elb-alb-not-public

  load_balancer_type         = "application"
  drop_invalid_header_fields = true
  security_groups           = [var.security_group]
  subnets                   = var.public_subnets

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "8081"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Redirect HTTP traffic to HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}