resource "aws_iam_role" "node" {
  name = substr("eks-node-${local.name2}", 0, 64)

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

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}": "owned",
    "superhub.io/stack/${var.domain_name}": "owned",
    "superhub.io/role/kind": "worker"
  }
}

# https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-03-23/amazon-eks-nodegroup-role.yaml

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_instance_profile" "node" {
  name = "eks-node-${local.name2}"
  role = aws_iam_role.node.name

  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# this is handled by EKS automatically
# resource "aws_security_group_rule" "managed_node_ssh" {
#   cidr_blocks       = ["0.0.0.0/0"]
#   ipv6_cidr_blocks  = ["::/0"]
#   description       = "Allow managed node SSH access"
#   from_port         = 22
#   protocol          = "tcp"
#   security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
#   to_port           = 22
#   type              = "ingress"
# }

resource "aws_security_group_rule" "shared_node_to_cluster" {
  description              = "Allow unmanaged nodes to communicate with managed workloads"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = local.shared_node_security_group_id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_to_shared_node" {
  description              = "Allow managed workloads to communicate with unmanaged nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = local.shared_node_security_group_id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  to_port                  = 65535
  type                     = "ingress"
}

locals {
  gpu_instance_types = [
    "p2.xlarge",
    "p2.8xlarge",
    "p2.16xlarge",
    "p3.2xlarge",
    "p3.8xlarge",
    "p3.16xlarge",
    "p3dn.24xlarge",
    "g3s.xlarge",
    "g3.4xlarge",
    "g3.8xlarge",
    "g3.16xlarge",
    "g4dn.xlarge",
    "g4dn.2xlarge",
    "g4dn.4xlarge",
    "g4dn.8xlarge",
    "g4dn.16xlarge",
    "g4dn.12xlarge",
    "g4dn.metal",
  ]
  worker_instance_gpu = contains(local.gpu_instance_types, var.worker_instance_type)
}
