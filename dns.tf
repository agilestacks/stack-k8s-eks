data "aws_route53_zone" "base" {
  provider = aws.dns

  name = var.base_domain
}

resource "aws_route53_zone" "cluster" {
  provider = aws.dns

  name          = "${var.name}.${data.aws_route53_zone.base.name}"
  force_destroy = true

  tags = {
    "superhub.io/stack/${var.name}.${var.base_domain}": "owned"
  }
}

resource "aws_route53_record" "ns" {
  provider = aws.dns

  zone_id = data.aws_route53_zone.base.zone_id
  name    = var.name
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.cluster.name_servers
}

resource "aws_route53_record" "api" {
  provider = aws.dns

  zone_id = aws_route53_zone.cluster.zone_id
  name    = "api"
  type    = "CNAME"
  ttl     = "300"
  records = [local.api_endpoint_host]
}

resource "aws_route53_record" "internal" {
  provider = aws.dns

  zone_id = aws_route53_zone.cluster.zone_id
  name    = "i"
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.internal.name_servers
}

resource "aws_route53_zone" "internal" {
  name = "i.${var.name}.${data.aws_route53_zone.base.name}"
  vpc {
    vpc_id = aws_vpc.cluster.id
  }
  force_destroy = true
}
