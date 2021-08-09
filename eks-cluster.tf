# https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-03-23/amazon-eks-vpc-sample.yaml

resource "aws_iam_role" "cluster" {
  name = substr("eks-cluster-${local.name2}", 0, 64)

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
# resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
#   policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSServicePolicy"
#   role       = aws_iam_role.cluster.name
# }

# https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = local.version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = local.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  dynamic encryption_config {
    for_each = var.key_arn != "" ? [1] : []
    content {
      provider {
        key_arn = var.key_arn
      }
      resources = ["secrets"]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    # aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSVPCResourceController,
  ]

  timeouts {
    create = "30m"
  }
}

data "tls_certificate" "oidc_issuer" {
  url = local.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_issuer.certificates[0].sha1_fingerprint]
  url             = local.oidc_issuer_url

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "superhub.io/stack/${var.domain_name}"      = "owned"
  }
}

# a role to annotate aws-node daemonset's service account for CNI permissions
data "aws_iam_policy_document" "oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_node" {
  name = substr("eks-aws-node-${local.name2}", 0, 64)

  assume_role_policy = data.aws_iam_policy_document.oidc.json

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}": "owned",
    "superhub.io/stack/${var.domain_name}": "owned",
    "superhub.io/role/kind": "aws-node"
  }
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.aws_node.name
}

locals {
  version           = var.k8s_version
  api_endpoint      = replace(aws_eks_cluster.main.endpoint, "/https://([^/]+).*/", "$1")
  api_endpoint_host = replace(local.api_endpoint, "/([^:]+).*/", "$1")
  oidc_issuer_url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_issuer       = replace(local.oidc_issuer_url, "/https://(.+)/", "$1")
}
