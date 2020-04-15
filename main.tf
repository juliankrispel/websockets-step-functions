provider "aws" {
  profile = "reactrocket"
  region  = "eu-west-2"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = file("policies/iam_for_lambda.json")
}

resource "aws_iam_role" "iam_for_sfn" {
  name = "iam_for_sfn"
  assume_role_policy = file("policies/iam_for_sfn.json")
}


resource "aws_lambda_function" "lambda" {
  for_each = fileset(path.module, "lambdas/*.js")

  filename      = each.value
  function_name = replace(basename(each.value), ".js", "")
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "exports.handler"

  source_code_hash = filebase64(each.value)
  runtime = "nodejs12.x"
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "websocket-state-machine"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = file("./states.json")
}