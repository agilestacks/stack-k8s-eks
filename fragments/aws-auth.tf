data "aws_iam_user" "admin" {
  for_each = toset(split(",", var.eks_admin))
  user_name = each.value
}

locals {
  admins = [for admin in data.aws_iam_user.admin: admin.arn]
  admins_yaml = <<EOT
%{ for arn in local.admins }
    - userarn: ${arn}
      username: ${split("/", arn)[1]}
      groups:
        - system:masters
%{ endfor }
EOT

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
${local.admins_yaml}
CONFIGMAPAWSAUTH

}
