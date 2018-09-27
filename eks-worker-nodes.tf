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

  # This is a convenient place to destroy stray ENIs left by node's amazon-vpc-cni-k8s.
  # We could piggyback on aws_launch_configuration.node instead, but EKS masters installs their own ENIs.
  provisioner "local-exec" {
    when       = "destroy"
    on_failure = "continue"
    command    = <<EOF
export AWS_DEFAULT_REGION=${data.aws_region.current.name}
aws ec2 describe-network-interfaces \
        --filters Name=vpc-id,Values=${aws_vpc.cluster.id} Name=status,Values=available \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' \
        --output text \
    | xargs -tn1 aws ec2 delete-network-interface --network-interface-id
EOF
  }
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
  description              = "Allow node Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster443" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.cluster.id}"
  to_port                  = 443
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

locals {
  gpu_instance_types = [
    "p2.xlarge",
    "p2.8xlarge",
    "p2.16xlarge",
    "p3.2xlarge",
    "p3.8xlarge",
    "p3.16xlarge",
    "g3.4xlarge",
    "g3.8xlarge",
    "g3.16xlarge"
  ]
  worker_instance_gpu = "${contains(local.gpu_instance_types, var.worker_instance_type)}"
}

# https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
# https://aws.amazon.com/blogs/opensource/improvements-eks-worker-node-provisioning/
# GPU users must subscribe to https://aws.amazon.com/marketplace/pp?sku=58kec53jbhfbaqpgzivdyhdo9
# Region                            Amazon EKS-optimized AMI  with GPU support
# US West (Oregon     ) (us-west-2) ami-0a54c984b9f908c81     ami-0731694d53ef9604b
# US East (N. Virginia) (us-east-1) ami-0440e4f6b9713faf6     ami-058bfb8c236caae89
# EU (Ireland)          (eu-west-1) ami-0c7a4976cb6fafd3a     ami-0706dc8a5eed2eed9
data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-*", "amazon-eks-gpu-node-*"]
  }

  most_recent = true
  owners      = ["${local.worker_instance_gpu ? "679593333241" : "602401143452"}"] # Amazon
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
    # ignore_changes        = ["image_id"]
  }

  root_block_device {
    volume_type = "${var.worker_root_volume_type}"
    volume_size = "${var.worker_root_volume_size}"
    iops        = "${var.worker_root_volume_type == "io1" ? var.worker_root_volume_iops : 0}"
  }
}

resource "aws_autoscaling_group" "nodes" {
  desired_capacity     = "${var.worker_count}"
  launch_configuration = "${aws_launch_configuration.node.id}"
  max_size             = 16
  min_size             = 1
  name                 = "eks-node-${local.name2}"
  vpc_zone_identifier  = ["${aws_subnet.nodes.*.id}"]

  depends_on = ["aws_eks_cluster.main"]

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
