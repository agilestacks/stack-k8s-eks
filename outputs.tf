resource "local_file" "ca_crt" {
  content  = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  filename = "${path.cwd}/.terraform/${var.domain_name}/ca.pem"
}

resource "local_file" "kubeconfig" {
  filename = "${path.cwd}/kubeconfig.${var.domain_name}"
  content  = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.main.endpoint}
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
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

output "api_ca_crt" {
  value = "file://${local_file.ca_crt.filename}"
}

output "api_endpoint" {
  value = local.api_endpoint
}

output "api_endpoint_cname" {
  value = aws_route53_record.api.fqdn
}

output "region" {
  value = data.aws_region.current.name
}

output "zone" {
  value = local.availability_zones[0]
}

output "zones" {
  value = join(",", local.availability_zones)
}

output "vpc" {
  value = aws_vpc.cluster.id
}

output "vpc_cidr_block" {
  value = aws_vpc.cluster.cidr_block
}

output "worker_subnet_id" {
  value = length(aws_subnet.nodes) > 0 ? aws_subnet.nodes[0].id : ""
}

output "worker_subnet_ids" {
  value = join(",", aws_subnet.nodes.*.id)
}

output "worker_sg_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "worker_instance_profile" {
  value = aws_iam_instance_profile.node.name
}

output "worker_role" {
  value = aws_iam_role.node.name
}
