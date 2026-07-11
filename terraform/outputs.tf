output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "node1_public_ip" {
  value = aws_instance.node1.public_ip
}

output "node1_private_ip" {
  value = aws_instance.node1.private_ip
}

output "node2_public_ip" {
  value = aws_instance.node2.public_ip
}

output "node2_private_ip" {
  value = aws_instance.node2.private_ip
}

output "alb_dns_name" {
  value = aws_lb.kibana_alb.dns_name
}
