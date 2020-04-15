provider "aws" {
  profile = "reactrocket"
  region  = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket = "jkrsp-tf-state"
    key    = "websocket-step-functions.tfstate"
    region = "eu-west-2"
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "sockets_iam_for_lambda"
  assume_role_policy = file("policies/iam_for_lambda.json")
}

resource "aws_iam_role" "iam_for_sfn" {
  name = "sockets_iam_for_sfn"
  assume_role_policy = file("policies/iam_for_sfn.json")
}

data "archive_file" "deployment_package" {
  for_each = fileset(path.module, "lambdas/*.js")

  type        = "zip"
  source_file = each.value
  output_path = "lambdas/${replace(basename(each.value), ".js", "")}.zip"
}

resource "aws_lambda_function" "lambda" {
  for_each = fileset(path.module, "lambdas/*.js")

  filename      = data.archive_file.deployment_package[each.value].output_path
  function_name = replace(basename(each.value), ".js", "")
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "exports.handler"

  source_code_hash = filebase64(each.value)
  runtime = "nodejs12.x"
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "websocket-state-machine"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = templatefile(
    "./states.json",
    { makeTaskArn = aws_lambda_function.lambda["lambdas/make-task.js"].arn }
  )
}
