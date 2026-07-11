terraform {
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------
# Networking Stack
# ---------------------------------------------------------
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "App-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags   = { Name = "App-IGW" }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-2" }
}

# Private Subnets
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "Private-Subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "Private-Subnet-2" }
}

# NAT Gateway (Required for Private Subnets to reach internet)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "NAT-EIP" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "App-NAT" }
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-RT" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "Private-RT" }
}

# Route Table Associations
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ---------------------------------------------------------
# Security Groups
# ---------------------------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Security group for Bastion Host"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

resource "aws_security_group" "elk_sg" {
  name        = "elk-security-group"
  description = "Security group for Elasticsearch and Kibana in Private Subnets"
  vpc_id      = aws_vpc.app_vpc.id

  # SSH from Bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Elasticsearch HTTP/Transport from VPC
  ingress {
    from_port   = 9200
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app_vpc.cidr_block]
  }

  # Kibana from ALB
  ingress {
    from_port       = 5601
    to_port         = 5601
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "elk-sg" }
}

# ---------------------------------------------------------
# EC2 Instances
# ---------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Bastion Instance (Public Subnet)
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  subnet_id     = aws_subnet.public_1.id

  tags = { Name = "bastion-host" }
}

# ELK Node 1 (Private Subnet 1)
resource "aws_instance" "node1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  subnet_id     = aws_subnet.private_1.id

  tags = {
    Name   = "elk-node-1"
    Role   = "elk"
    Kibana = "true"
  }
}

# ELK Node 2 (Private Subnet 2)
resource "aws_instance" "node2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  subnet_id     = aws_subnet.private_2.id

  tags = {
    Name = "elk-node-2"
    Role = "elk"
  }
}

# ---------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------
resource "aws_lb" "kibana_alb" {
  name               = "kibana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "kibana_tg" {
  name     = "kibana-tg"
  port     = 5601
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id

  health_check {
    path                = "/api/status"
    port                = "5601"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "kibana_attachment" {
  target_group_arn = aws_lb_target_group.kibana_tg.arn
  target_id        = aws_instance.node1.id
  port             = 5601
}

resource "aws_lb_listener" "kibana_listener" {
  load_balancer_arn = aws_lb.kibana_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kibana_tg.arn
  }
}
