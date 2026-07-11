variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c7i-flex.large"
}

variable "key_name" {
  description = "Name of the existing SSH key pair in AWS"
  type        = string
  default     = "anshul-pem" # Using the provided key name
}
