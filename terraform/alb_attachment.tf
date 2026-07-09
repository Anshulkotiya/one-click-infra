resource "aws_lb_target_group_attachment" "kibana" {

  target_group_arn = aws_lb_target_group.kibana_tg.arn

  target_id = aws_instance.kibana.id

  port = var.kibana_port
}

resource "aws_lb_target_group_attachment" "elasticsearch" {
  target_group_arn = aws_lb_target_group.kibana_tg.arn
  target_id        = aws_instance.elasticsearch.id
  port             = var.kibana_port
}
