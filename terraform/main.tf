terraform {  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
      }
  }
}
provider aws {
    region     = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_route53_zone" "base" {
  name         = var.base_domain

}

resource "aws_s3_bucket" "dyndns" {
  bucket = "${var.sub_domain}-config-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  tags   = {"App" = "dyndns"}
}


output "invoke_url" {
  value = aws_api_gateway_stage.dyndns_prod.invoke_url
}