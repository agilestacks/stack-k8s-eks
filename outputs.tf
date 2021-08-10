output "api_ca_crt" {
  value = "file://${local_file.ca_crt.filename}"
}

output "api_endpoint" {
  value = local.api_endpoint
}

output "api_endpoint_cname" {
  value = aws_route53_record.api.fqdn
}

output "oidc_issuer" {
  value = local.oidc_issuer
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
  value = local.vpc_id
}

output "vpc_cidr_block" {
  value = local.vpc_cidr_block
}

output "worker_subnet_id" {
  value = local.subnet_ids[0]
}

output "worker_subnet_ids" {
  value = join(",", local.subnet_ids)
}

output "worker_sg_id" {
  value = local.shared_node_security_group_id
}

output "worker_instance_profile" {
  value = aws_iam_instance_profile.node.name
}

output "worker_role_name" {
  value = aws_iam_role.node.name
}

output "aws_node_role_arn" {
  value = aws_iam_role.aws_node.arn
}
