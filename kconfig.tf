resource "local_file" "ca_crt" {
  filename        = "${path.cwd}/.terraform/${var.domain_name}/ca.pem"
  file_permission = "0660"
  content         = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
}

resource "local_file" "kubeconfig" {
  filename        = "${path.cwd}/kubeconfig.${var.domain_name}"
  file_permission = "0660"

  content = <<KUBECONFIG
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
