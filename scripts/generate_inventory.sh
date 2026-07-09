#!/usr/bin/env bash
# Generates ansible/inventory/hosts.ini by:
#   1. Reading the bastion public IP from Terraform output
#   2. Asking AWS (via the ASG name) for the current private IPs of app nodes
#   3. Writing an inventory where each app node is reached by SSH-jumping
#      through the bastion host (no direct SSH exposure to the private nodes)
#
# Usage:
#   ./generate_inventory.sh <terraform_dir> <ssh_private_key_path> <output_inventory_path>
#
# Requires: terraform, aws-cli, jq

set -euo pipefail

TF_DIR="${1:?terraform dir required}"
SSH_KEY="${2:?path to ssh private key required}"
OUT_FILE="${3:?output inventory path required}"

cd "$TF_DIR"

BASTION_IP=$(terraform output -raw bastion_public_ip)
ASG_NAME=$(terraform output -raw asg_name)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-south-1")

echo "Bastion IP : $BASTION_IP"
echo "ASG name   : $ASG_NAME"

# Get instance IDs currently in the ASG, then their private IPs
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$REGION" \
  --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "ERROR: No InService instances found in ASG $ASG_NAME" >&2
  exit 1
fi

PRIVATE_IPS=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --region "$REGION" \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text)

echo "App node private IPs: $PRIVATE_IPS"

mkdir -p "$(dirname "$OUT_FILE")"

{
  echo "[elastic_servers]"
  for ip in $PRIVATE_IPS; do
    echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY} ansible_python_interpreter=/usr/bin/python3 ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@${BASTION_IP}\"'"
  done
} > "$OUT_FILE"

echo "Inventory written to $OUT_FILE"
cat "$OUT_FILE"
