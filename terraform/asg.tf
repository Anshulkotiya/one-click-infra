#############################################
# Auto Scaling Group — spans both private subnets (ap-south-1a / ap-south-1b)
#############################################
resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.project_name}-app-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  health_check_type   = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.kibana_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-Kibana-EC2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.tags["Project"]
    propagate_at_launch = true
  }

  # So Jenkins/CI can discover instances via `aws ec2 describe-instances`
  tag {
    key                 = "elk:role"
    value               = "app-node"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
