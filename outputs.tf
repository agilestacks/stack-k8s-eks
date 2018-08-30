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
  value = "${replace(aws_eks_cluster.main.endpoint, "/https://([^/]+).*/", "$1")}"
}
