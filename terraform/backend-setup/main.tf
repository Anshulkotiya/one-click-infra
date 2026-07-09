# ============================================================================
# RUN THIS ONCE, MANUALLY, BEFORE THE MAIN TERRAFORM / JENKINS PIPELINE.
#
#   cd terraform/backend-setup
#   terraform init
#   terraform apply
#
# This config has its own *local* state (chicken-and-egg problem: you can't
# store state for the bucket inside the bucket it creates). Keep its
# terraform.tfstate file safe (commit to a private repo or move to a
# separate, already-existing bucket) — you'll rarely need to touch it again.
#
# NOTE: Kept simple on purpose — just an S3 bucket for state, no DynamoDB
# lock table. Fine for solo/small-team use; just avoid running `terraform
# apply` from two places at the same time.
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state"
  type        = string
  default     = "my-terraform-assignment-bucket"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Prevent `terraform destroy` from ever silently deleting your state history
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = var.state_bucket_name
    Purpose = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
