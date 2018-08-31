resource "aws_iam_role" "node" {
  name = "eks-node-${local.name2}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_instance_profile" "node" {
  name = "eks-node-${local.name2}"
  role = "${aws_iam_role.node.name}"
}

resource "aws_security_group" "node" {
  name        = "eks-node-${local.name2}"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.cluster.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "eks-node-${local.name2}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ssh" {
  cidr_blocks              = ["0.0.0.0/0"]
  ipv6_cidr_blocks         = ["::/0"]
  description              = "Allow node SSH access"
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  to_port                  = 22
  type                     = "ingress"
}

# https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
# Region                            Amazon EKS-optimized AMI  with GPU support
# US West (Oregon) (us-west-2)      ami-08cab282f9979fc7a     ami-0d20f2404b9a1c4d1
# US East (N. Virginia) (us-east-1) ami-0b2ae3c6bda8b5c06     ami-09fe6fc9106bda972
data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon
}

# https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2018-08-21/amazon-eks-nodegroup.yaml
locals {
  userdata = <<USERDATA
#!/bin/sh
exec /etc/eks/bootstrap.sh ${var.cluster_name}
USERDATA
}

resource "aws_launch_configuration" "node" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.node.name}"
  image_id                    = "${data.aws_ami.eks_worker.id}"
  instance_type               = "${var.worker_instance_type}"
  key_name                    = "${var.keypair}"
  name_prefix                 = "eks-node-${local.name2}"
  security_groups             = ["${aws_security_group.node.id}"]
  spot_price                  = "${var.worker_spot_price}"
  user_data_base64            = "${base64encode(local.userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodes" {
  desired_capacity     = "${var.worker_count}"
  launch_configuration = "${aws_launch_configuration.node.id}"
  max_size             = 16
  min_size             = 1
  name                 = "eks-node-${local.name2}"
  vpc_zone_identifier  = ["${aws_subnet.nodes.*.id}"]

  tag {
    key                 = "Name"
    value               = "eks-node-${local.name2}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
