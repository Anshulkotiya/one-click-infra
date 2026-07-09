#############################################
# ALB — public facing, forwards to Kibana on app nodes
#############################################
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-ALB"
  })
}

resource "aws_lb_target_group" "kibana_tg" {
  name     = "${var.project_name}-kibana-tg"
  port     = var.kibana_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id

  health_check {
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-Target-Group"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kibana_tg.arn
  }
}

# NOTE: For HTTPS, request/import an ACM certificate and add an
# aws_lb_listener on port 443 with protocol = "HTTPS" and ssl_policy set,
# then redirect the port-80 listener to HTTPS instead of forwarding directly.
