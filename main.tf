provider "aws" {
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
  assume_role_policy = file("policies/assume_role.json")
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy"
  policy = file("policies/iam_for_lambda.json")
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role" "iam_for_sfn" {
  name = "sockets_iam_for_sfn"
  assume_role_policy = file("policies/assume_role.json")
}

resource "aws_iam_policy" "sfn_policy" {
  name        = "sfn-policy"
  policy = file("policies/iam_for_sfn.json")
}

resource "aws_iam_role_policy_attachment" "sfn_policy_attachment" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}

resource "aws_iam_role" "iam_for_apig" {
  name = "sockets_iam_for_apig"
  assume_role_policy = file("policies/assume_role.json")
}

resource "aws_iam_policy" "apig_policy" {
  name        = "apig-policy"
  policy = file("policies/iam_for_apig.json")
}

resource "aws_iam_role_policy_attachment" "apig_policy_attachment" {
  role       = aws_iam_role.iam_for_apig.name
  policy_arn = aws_iam_policy.apig_policy.arn
}

data "archive_file" "deployment_package" {
  for_each = fileset(path.module, "lambdas/*.js")

  type        = "zip"
  source_file = each.value
  output_path = "lambdas/${replace(basename(each.value), ".js", "")}.zip"
}

resource "aws_lambda_function" "start_step_function" {
  filename      = data.archive_file.deployment_package["lambdas/start-step-function.js"].output_path
  function_name = "start-step-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "start-step-function.handler"

  source_code_hash = filebase64("lambdas/start-step-function.js")
  runtime = "nodejs12.x"

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.state_machine.id
    }
  }
}

resource "aws_lambda_function" "make_task" {
  filename      = data.archive_file.deployment_package["lambdas/make-task.js"].output_path
  function_name = "make-task"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "make-task.handler"

  source_code_hash = filebase64("lambdas/make-task.js")
  runtime = "nodejs12.x"

  environment {
    variables = {
      CONNECTION_URL = "https://${aws_apigatewayv2_api.websocket_api.id}.execute-api.eu-west-2.amazonaws.com/${aws_apigatewayv2_stage.v1.id}"
    }
  }
}

resource "aws_lambda_function" "stop_execution" {
  filename      = data.archive_file.deployment_package["lambdas/stop-execution.js"].output_path
  function_name = "stop-execution"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "stop-execution.handler"

  source_code_hash = filebase64("lambdas/stop-execution.js")
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "succeed_task" {
  filename      = data.archive_file.deployment_package["lambdas/succeed-task.js"].output_path
  function_name = "succeed-task"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "succeed-task.handler"

  source_code_hash = filebase64("lambdas/succeed-task.js")
  runtime = "nodejs12.x"
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "websocket-state-machine"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = templatefile(
    "./states.json",
    { makeTaskArn = aws_lambda_function.make_task.arn }
  )
}

resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "state-machine-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}


resource "aws_apigatewayv2_integration" "start_step_function" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.start_step_function.invoke_arn
  integration_method = "POST"
  credentials_arn = aws_iam_role.iam_for_apig.arn

}

resource "aws_apigatewayv2_route" "connect" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target = "integrations/${aws_apigatewayv2_integration.start_step_function.id}"
}

resource "aws_apigatewayv2_integration" "stop_step_function" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.stop_execution.invoke_arn
  integration_method = "POST"
  credentials_arn = aws_iam_role.iam_for_apig.arn
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target = "integrations/${aws_apigatewayv2_integration.stop_step_function.id}"
}

resource "aws_apigatewayv2_integration" "succeed_task" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.succeed_task.invoke_arn
  integration_method = "POST"
  credentials_arn = aws_iam_role.iam_for_apig.arn
}

resource "aws_apigatewayv2_route" "default" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.succeed_task.id}"
}


resource "aws_apigatewayv2_deployment" "websocket_api" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  description = "Websocket deployment"
  depends_on = ["aws_apigatewayv2_route.default", "aws_apigatewayv2_route.disconnect", "aws_apigatewayv2_route.connect"]
}

resource "aws_apigatewayv2_stage" "v1" {
  api_id = aws_apigatewayv2_api.websocket_api.id
  name   = "v1"
  deployment_id = aws_apigatewayv2_deployment.websocket_api.id

  default_route_settings {
    logging_level = "INFO"
    data_trace_enabled = true
    detailed_metrics_enabled = true
    throttling_burst_limit = 10000
    throttling_rate_limit = 10000
  }
}
