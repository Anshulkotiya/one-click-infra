output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.app_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host — used as SSH jump host for Ansible"
  value       = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB — open this in a browser to reach Kibana"
  value       = aws_lb.app_alb.dns_name
}

output "asg_name" {
  description = "Auto Scaling Group name — Jenkins uses this to discover current app node private IPs"
  value       = aws_autoscaling_group.app_asg.name
}

output "app_security_group_id" {
  value = aws_security_group.app_sg.id
}
