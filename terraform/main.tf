provider "aws" {
  region     = "us-east-1"
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_route53_zone" "base" {
  name         = var.base_domain

}

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

resource "aws_s3_bucket" "dyndns" {
  bucket = "${var.sub_domain}-config-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  tags   = {"App" = "dyndns"}
}