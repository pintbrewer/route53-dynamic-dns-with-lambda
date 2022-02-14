provider "aws" {
  region     = "us-east-1"
  version = "~> 3.0"
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

resource "aws_lambda_function" "dyndns" {
  filename = "../v2/dist/dynamic_dns_lambda.zip"
  function_name = "dyndns"
  role = "${aws_iam_role.dyndns.arn}"
  handler = "dynamic_dns_lambda.lambda_handler"
  runtime = "python3.6"
  timeout = "10"
  memory_size = "128"
  publish = true
  environment  {
    variables = {
      config_s3_region = "${data.aws_region.current.name}",
      config_s3_bucket = "${aws_s3_bucket.dyndns.bucket}",
      config_s3_key = "config.json"
    }
  }
  tags = {"App" = "dyndns"}
} 

resource "aws_iam_role" "dyndns" {
  name = "dynamic_dns_lambda_execution_role"
  description = "Allows Lambda functions to call AWS services on your behalf."
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  tags = {"App" = "dyndns"}
}

resource "aws_iam_policy" "dyndns" {
  name = "dynamic_dns_lambda_execution_policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:415752730261:log-group:*:log-stream:*",
                "${aws_route53_zone.ddns_zone.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "route53:ListResourceRecordSets",
                "logs:CreateLogGroup"
            ],
            "Resource": [
                "${aws_route53_zone.ddns_zone.arn}",
                "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "${aws_s3_bucket.dyndns.arn}",
                "${aws_s3_bucket.dyndns.arn}/*"
            ]
        }
    ]
}
EOF
  tags = {"App" = "dyndns"}
}

resource "aws_iam_role_policy_attachment" "dyndns" {
  role = "${aws_iam_role.dyndns.name}"
  policy_arn = "${aws_iam_policy.dyndns.arn}"
}

resource "aws_api_gateway_rest_api" "dyndns" {
  name        = "dynamic_dns_lambda_api"
}

resource "aws_api_gateway_resource" "dyndns" {
  rest_api_id = "${aws_api_gateway_rest_api.dyndns.id}"
  parent_id   = ""
  path_part   = ""
}

resource "aws_api_gateway_model" "setdns" {
  rest_api_id  = aws_api_gateway_rest_api.dyndns.id
  name         = "setdns"
  content_type = "application/json"

  schema = <<EOF
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "DnsSetModel",
  "type": "object",
  "properties": {
    "department": { "type": "string" },
    "hostname": {"type":"string"},
    "hash": {"type": "string"}
  }
}
EOF
}

resource "aws_api_gateway_method" "dyndns_get" {  
  rest_api_id = "${aws_api_gateway_rest_api.dyndns.id}"
  resource_id = "${aws_api_gateway_resource.dyndns.id}"
  http_method = "GET"
  authorization = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.querystring.hash" = false,
    "method.request.querystring.hostname" = false,
    "method.request.querystring.mode" = false,
  }
}
resource "aws_api_gateway_method" "dyndns_post" {
  rest_api_id = "${aws_api_gateway_rest_api.dyndns.id}"
  resource_id = "${aws_api_gateway_resource.dyndns.id}"
  http_method = "POST"
  authorization = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.querystring.mode" = false,
  }
  request_models = {
    "application/json" = "setdns"
  }

}

resource "aws_api_gateway_integration" "integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.dyndns.id
  resource_id             = aws_api_gateway_resource.dyndns.id
  http_method             = aws_api_gateway_method.dyndns_get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.dyndns.invoke_arn
}
resource "aws_api_gateway_integration" "integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.dyndns.id
  resource_id             = aws_api_gateway_resource.dyndns.id
  http_method             = aws_api_gateway_method.dyndns_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.dyndns.invoke_arn
  content_handling = "CONVERT_TO_TEXT"
  request_templates = {
    "application/json" = <<EOF
{
  "execution_mode" : "$input.params('mode')",
  "set_hostname" : $input.json('$.host'),
  "validation_hash" : $input.json('$.hash'),
  "source_ip" : "$context.identity.sourceIp",
  "query_string" : "$input.params().querystring",
  "internal_ip" : "$input.params('internalIp')"
}
EOF
  }

}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dyndns.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.dyndns.id}/*/${aws_api_gateway_method.dyndns_get.http_method}${aws_api_gateway_resource.dyndns.path}"
}
resource "aws_lambda_permission" "apigw_lambda_post" {
  statement_id  = "AllowExecutionFromAPIGatewayPost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dyndns.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.dyndns.id}/*/${aws_api_gateway_method.dyndns_post.http_method}${aws_api_gateway_resource.dyndns.path}"
}
resource "aws_api_gateway_deployment" "dyndns" {
  rest_api_id = aws_api_gateway_rest_api.dyndns.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.dyndns.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "dyndns_prod" {
  deployment_id = aws_api_gateway_deployment.dyndns.id
  rest_api_id   = aws_api_gateway_rest_api.dyndns.id
  stage_name    = "prod"
  cache_cluster_size = "0.5"
}

resource "aws_api_gateway_usage_plan" "dyndns" {
  name         = "dyndns-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.dyndns.id
    stage  = aws_api_gateway_stage.dyndns_prod.stage_name
  }

  quota_settings {
    limit  = 20
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

resource "aws_api_gateway_api_key" "dyndns" {
  name = "dyndns_key"
}

resource "aws_api_gateway_usage_plan_key" "dyndns" {
  key_id        = aws_api_gateway_api_key.dyndns.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.dyndns.id
}

output "invoke_url" {
  value = aws_api_gateway_stage.dyndns_prod.invoke_url
}