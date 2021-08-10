data "aws_route53_zone" "cluster" {
  provider = aws.dns

  name = var.domain_name
}

locals {
  zone_id = data.aws_route53_zone.cluster.zone_id
}
