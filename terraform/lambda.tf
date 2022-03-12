resource "aws_lambda_function" "dyndns" {
  filename = "../v2/dist/dynamic_dns_lambda.zip"
  function_name = "dyndns"
  role = "${aws_iam_role.dyndns.arn}"
  handler = "dynamic_dns_lambda.lambda_handler"
  runtime = "python3.6"
  timeout = "10"
  memory_size = "128"
  publish = true
  source_code_hash = filebase64sha256("../v2/dist/dynamic_dns_lambda.zip")
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
