# The application load balancer fronts the API service and routes traffic to healthy ECS tasks.
resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [var.sg_id]
}

resource "aws_lb_target_group" "api" {
  name        = "${var.name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
