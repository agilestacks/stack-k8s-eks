resource "aws_route53_record" "api" {
  provider = aws.dns

  zone_id = local.zone_id
  name    = "api"
  type    = "CNAME"
  ttl     = "300"
  records = [local.api_endpoint_host]
}
