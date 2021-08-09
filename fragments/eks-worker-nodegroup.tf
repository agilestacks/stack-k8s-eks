resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "initial"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids

  scaling_config {
    desired_size = var.worker_count
    min_size     = var.worker_count
    max_size     = var.worker_max_count
  }

  ami_type       = "AL2_x86_64${local.worker_instance_gpu ? "_GPU" : ""}"
  disk_size      = var.worker_root_volume_size
  instance_types = [var.worker_instance_type]
  # TODO
  # capacity_type =
  labels         = {for label in split(",", var.worker_labels) : split("=", label)[0] => split("=", label)[1]}
  # TODO pre-bootstrap userdata via aws_launch_template.user_data
  # launch_template =

  remote_access {
    ec2_ssh_key = var.keypair
  }

  tags = {
    Name = "eks-nodegroup-${aws_eks_cluster.main.name}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly,
  ]
}
