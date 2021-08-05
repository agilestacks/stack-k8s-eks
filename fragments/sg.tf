resource "aws_security_group" "nodes" {
  name        = "${local.name2}-nodes"
  description = "All nodes in the cluster"
  vpc_id      = local.vpc_id

  tags = {
    "Name"                                      = "${local.name2}-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "superhub.io/stack/${var.domain_name}"      = "owned"
  }
}

locals {
    shared_node_security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow nodes to communicate with external world"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nodes.id
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_icmp" {
  description       = "Allow nodes ICMP access"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = "-1"
  protocol          = "icmp"
  security_group_id = aws_security_group.nodes.id
  to_port           = "-1"
  type              = "ingress"
}

resource "aws_security_group_rule" "nodes_ssh" {
  description       = "Allow nodes SSH access"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.nodes.id
  to_port           = 22
  type              = "ingress"
}
