resource "aws_instance" "elasticsearch" {

  ami = data.aws_ami.ubuntu.id

  instance_type = var.app_instance_type

  subnet_id = aws_subnet.private[0].id

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  key_name = var.key_name


  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }


  tags = merge(var.tags, {
    Name = "${var.project_name}-Elasticsearch"
    Role = "elasticsearch"
  })
}
