# resource "aws_iam_role_policy" "node" {
#   name = "BasicCloud"
#   role = aws_iam_role.node.id

#   policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Resource": "*",
#       "Action": [
#         "autoscaling:*",
#         "cloudwatch:*",
#         "dynamodb:*",
#         "ec2:*",
#         "ecr:*",
#         "elasticloadbalancing:*",
#         "route53:*",
#         "s3:*",
#         "sts:*",
#         "iam:CreateServiceLinkedRole"
#       ]
#     }
#   ]
# }
# POLICY

# }
