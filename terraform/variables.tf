variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1" # Mumbai
}

variable "project_name" {
  description = "Prefix used to tag/name all resources"
  type        = string
  default     = "elk"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (2 for HA, matches diagram: ap-south-1a / ap-south-1b)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets (bastion + ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets (Elasticsearch/Kibana/Logstash/Filebeat app nodes)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "key_name" {
  description = "Existing EC2 key pair name used for SSH (bastion + app nodes)"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the bastion host. Defaults to open (0.0.0.0/0) for simplicity."
  type        = string
  default     = "0.0.0.0/0"
}


variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "Instance type for Elasticsearch/Kibana app nodes (ES benefits from more RAM)"
  type        = string
  default     = "c7i-flex.large"
}

variable "asg_min_size" {
  description = "Minimum number of app instances"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of app instances"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of app instances (one per private subnet by default, matches diagram)"
  type        = number
  default     = 2
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB) for app nodes — Elasticsearch needs headroom for indices"
  type        = number
  default     = 30
}

variable "kibana_port" {
  description = "Kibana HTTP port (must match ansible playbook.yml kibana_port var)"
  type        = number
  default     = 5601
}

variable "elasticsearch_port" {
  description = "Elasticsearch HTTP port (must match ansible playbook.yml elasticsearch_port var)"
  type        = number
  default     = 9200
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "elk-one-click-infra"
    ManagedBy = "terraform"
  }
}
