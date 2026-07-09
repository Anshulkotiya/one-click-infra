#############################################
# Launch Template — Elasticsearch/Kibana/Logstash/Filebeat app nodes
# (Actual ES/Kibana install & config is done by the Ansible playbook after
#  Terraform brings the instances up — user_data only prepares the box.)
#############################################
locals {
  app_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y python3 python3-apt curl unzip
    # Instance is now ready for Ansible to connect over SSH (via bastion)
    # and install/configure Elasticsearch + Kibana.
  EOF
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.app_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(local.app_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_name}-Kibana-EC2"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}
