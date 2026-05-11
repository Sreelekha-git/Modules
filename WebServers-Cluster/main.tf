locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
}

resource "aws_launch_template" "webserver" {
  name_prefix   = "${var.Cluster_Name}-webserver"
  image_id      = "ami-07a00cf47dbbc844c"
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.sg.id]

// Check out passing a file instead of content direcly here
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "Hello World!!!" > index.html
    nohup busybox httpd -f -p ${local.http_port} &
    EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = 2
  launch_template {
    id = aws_launch_template.webserver.id
  }
  target_group_arns = [aws_lb_target_group.LB_target_group.arn]

  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_type        = "ELB"
  tag {
    key                 = "Name"
    value               = "${var.Cluster_Name}-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  scheduled_action_name = "scale-out-during-business-hours"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = 2
  recurrence = "0 9 * * *"
}
resource "aws_autoscaling_schedule" "scale_in_night" {
  scheduled_action_name = "scale-in-night"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = 2
  recurrence = "0 17 * * *"
}

resource "aws_lb" "LB" {
  name = "${var.Cluster_Name}-lb"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.sg.id]
}

resource "aws_lb_listener" "LB_listener" {
  load_balancer_arn = aws_lb.LB.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Hello from the Load Balancer!"
      status_code  = "200"
    }
  }
}

resource "aws_lb_target_group" "LB_target_group" {
  name     = "${var.Cluster_Name}-asg"
  port     = local.http_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "LB_listener_rule" {
  listener_arn = aws_lb_listener.LB_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.LB_target_group.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

# resource "aws_security_group" "sg" { // To be able to add extra security rules in future if needed, we can use security_group_rules instead of inline rules in LB and ASG. For now, we will keep it simple and use inline rules in ASG.
#   name        = "${var.Cluster_Name}-sg"
#   description = "Security group for LB web servers"

#   ingress {
#     from_port   = local.http_port
#     to_port     = local.http_port
#     protocol    = local.tcp_protocol
#     cidr_blocks = local.all_ips
#   }
#   egress {
#     from_port   = local.any_port
#     to_port     = local.any_port
#     protocol    = local.any_protocol
#     cidr_blocks = local.all_ips
#   }
# }   

resource "aws_security_group" "sg" {
  name        = "${var.Cluster_Name}-sg"
  description = "Security group for LB web servers"
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  cidr_blocks       = local.all_ips
  security_group_id = aws_security_group.sg.id
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"]
  }
}