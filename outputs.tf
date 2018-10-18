data "aws_iam_user" "admin" {
  user_name = "${var.eks_admin}"
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: ${data.aws_iam_user.admin.arn}
      username: admin
      groups:
        - system:masters
CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.main.endpoint}
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority.0.data}
  name: ${var.domain_name}
contexts:
- context:
    cluster: ${var.domain_name}
    namespace: kube-system
    user: admin@${var.domain_name}
  name: ${var.domain_name}
current-context: ${var.domain_name}
kind: Config
preferences: {}
users:
- name: admin@${var.domain_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
KUBECONFIG
}

resource "local_file" "ca_crt" {
  content  = "${base64decode(aws_eks_cluster.main.certificate_authority.0.data)}"
  filename = "${path.cwd}/.terraform/${var.domain_name}-ca.pem"
}

resource "local_file" "aws_auth" {
  content  = "${local.config_map_aws_auth}"
  filename = "${path.cwd}/.terraform/${var.domain_name}-aws-auth.yaml"
}

resource "local_file" "kubeconfig" {
  content  = "${local.kubeconfig}"
  filename = "${path.cwd}/kubeconfig.${var.domain_name}"
}

output "api_ca_crt" {
  value = "file://${local_file.ca_crt.filename}"
}

output "api_endpoint" {
  value = "${local.api_endpoint}"
}

output "api_endpoint_cname" {
  value = "${aws_route53_record.api.fqdn}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.files.bucket}"
}

output "region" {
  value = "${data.aws_region.current.name}"
}

output "zone" {
  value = "${local.availability_zones[0]}"
}

output "zones" {
  value = "${join(",", local.availability_zones)}"
}

output "vpc" {
  value = "${aws_vpc.cluster.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.cluster.cidr_block}"
}

output "worker_subnet_id" {
  value = "${aws_subnet.nodes.0.id}"
}

output "worker_subnet_ids" {
  value = "${join(",", aws_subnet.nodes.*.id)}"
}

output "worker_sg_id" {
  value = "${aws_security_group.node.id}"
}

output "worker_instance_profile" {
  value = "${aws_iam_instance_profile.node.name}"
}

output "worker_role" {
  value = "${aws_iam_role.node.name}"
}

output "master_role" {
  value = "${aws_iam_role.cluster.name}"
}
