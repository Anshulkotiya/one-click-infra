#############################################
# Private-NACL — attached to both private subnets
# Stateless: explicit inbound + outbound rules required.
#############################################
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.app_vpc.id
  subnet_ids = aws_subnet.private[*].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-Private-NACL"
  })
}

# Inbound: allow all traffic originating inside the VPC (ALB health checks,
# bastion SSH, inter-node ES traffic, etc.)
resource "aws_network_acl_rule" "private_in_vpc" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

# Inbound: allow ephemeral-port return traffic for outbound calls that went
# through the NAT Gateway (e.g. apt package downloads).
resource "aws_network_acl_rule" "private_in_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Outbound: allow all traffic within the VPC
resource "aws_network_acl_rule" "private_out_vpc" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

# Outbound: allow all traffic to the internet (via NAT) for package installs
resource "aws_network_acl_rule" "private_out_internet" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}
