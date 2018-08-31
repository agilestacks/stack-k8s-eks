# S3

locals {
  default_bucket = "files.${var.domain_name}"
}

resource "aws_s3_bucket" "files" {
  bucket = "${coalesce(var.bucket, local.default_bucket)}"
  acl = "private"
  force_destroy = true
  lifecycle {
    ignore_changes = ["*"]
  }
}

# DNS

data "aws_route53_zone" "base" {
  name = "${var.base_domain}"
}

resource "aws_route53_zone" "main" {
  name          = "${var.name}.${data.aws_route53_zone.base.name}"
  force_destroy = true
}

resource "aws_route53_record" "parent" {
  zone_id = "${data.aws_route53_zone.base.zone_id}"
  name    = "${var.name}"
  type    = "NS"
  ttl     = "60"
  records = ["${aws_route53_zone.main.name_servers}"]
}

resource "aws_route53_zone" "internal" {
  name          = "i.${var.name}.${data.aws_route53_zone.base.name}"
  vpc_id        = "${aws_vpc.cluster.id}"
  force_destroy = true
}

resource "aws_route53_record" "internal" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "i"
  type    = "NS"
  ttl     = "60"
  records = ["${aws_route53_zone.internal.name_servers}"]
}

resource "aws_route53_record" "api" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "api"
  type    = "CNAME"
  ttl     = "60"
  records = ["${local.api_endpoint_host}"]
}
