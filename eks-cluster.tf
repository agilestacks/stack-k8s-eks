# https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-03-23/amazon-eks-vpc-sample.yaml

resource "aws_iam_role" "cluster" {
  name = "eks-cluster-${local.name2}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# TODO should this go away?
# Prior to April 16, 2020, ManagedPolicyArns had an entry for arn:aws:iam::aws:policy/AmazonEKSServicePolicy.
# With the AWSServiceRoleForAmazonEKS service-linked role, that policy is no longer required.
resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = local.version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = aws_subnet.nodes.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]

  timeouts {
    create = "30m"
  }
}

locals {
  version           = "1.16"
  api_endpoint      = replace(aws_eks_cluster.main.endpoint, "/https://([^/]+).*/", "$1")
  api_endpoint_host = replace(local.api_endpoint, "/([^:]+).*/", "$1")
}
