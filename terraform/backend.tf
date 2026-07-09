# Partial backend configuration.
# Bucket name is injected at `terraform init` time via -backend-config
# (see Jenkinsfile) so the same code works across environments without
# hardcoding a bucket name here.
#
# Example manual init:
#   terraform init \
#     -backend-config="bucket=my-terraform-assignment-bucket" \
#     -backend-config="key=elk-infra/terraform.tfstate" \
#     -backend-config="region=ap-south-1" \
#     -backend-config="encrypt=true"
#
# NOTE: Kept simple — no DynamoDB lock table. Just don't run `terraform
# apply` from two places at once. The bucket itself is created once via
# terraform/backend-setup (a separate, self-contained Terraform config).

terraform {
  backend "s3" {}
}
