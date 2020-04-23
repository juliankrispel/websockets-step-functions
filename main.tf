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

data "template_file" "api-route" {
  template = file("${path.module}/api-route.tpl")
}

data "template_file" "api-integration" {
  template = file("${path.module}/api-integration.tpl")
}

resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "state-machine-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "start_step_function" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.lambda["lambdas/start-step-functions.js"]
}

resource "aws_apigatewayv2_route" "connect" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target = aws_apigatewayv2_integration.start_step_function.id
}

resource "aws_apigatewayv2_integration" "stop_step_function" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.lambda["lambdas/stop-execution.js"]
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target = aws_apigatewayv2_integration.stop_step_function.id
}

resource "aws_apigatewayv2_integration" "succeed_task" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.lambda["lambdas/succeed-task.js"]
}

resource "aws_apigatewayv2_route" "default" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target = aws_apigatewayv2_integration.succeed_task.id
}
