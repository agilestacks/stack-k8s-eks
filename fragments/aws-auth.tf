data "aws_iam_user" "admin" {
  user_name = var.eks_admin
}

resource "local_file" "aws_auth" {
  filename        = "${path.cwd}/.terraform/${var.domain_name}/aws-auth.yaml"
  file_permission = "0660"

  content = <<CONFIGMAPAWSAUTH
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

}
