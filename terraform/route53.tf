resource "aws_route53_zone" "ddns_zone" {
  name = "${var.sub_domain}.${var.base_domain}"
  tags =  {"App" = "dyndns"}
}

resource "aws_route53_record" "ddns_ns" {
  zone_id = data.aws_route53_zone.base.zone_id
  name    = "${var.sub_domain}.${var.base_domain}"
  type    = "NS"
  ttl     = "60"
  records = formatlist("%s.", aws_route53_zone.ddns_zone.name_servers)
  #aws_route53_zone.ddns_zone.name_servers
}

# May need to add the record?