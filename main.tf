provider "aws" {
  profile = "reactrocket"
  region  = "eu-west-2"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "test_lambda" {
  for_each = fileset(path.module, "lambdas/*.js")

  filename      = each.value
  function_name = each.value
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "exports.handler"

  source_code_hash = filebase64(each.value)
  runtime = "nodejs12.x"
}