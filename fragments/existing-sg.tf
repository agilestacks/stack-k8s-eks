data "aws_security_group" "nodes" {
  id = var.worker_sg_id
}

locals {
    shared_node_security_group_id = data.aws_security_group.nodes.id
}
