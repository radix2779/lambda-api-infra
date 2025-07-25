variable "region" {}
variable "account_id" {}
variable "lambda_json_invoke_arn" {}
variable "lambda_json_function_name" {}
variable "project_prefix" {}
variable "api_path" {}


# https://www.terraform.io/docs/providers/aws/r/api_gateway_rest_api.html
resource "aws_api_gateway_rest_api" "example_api" {
  name = var.project_prefix
}

# equivalent to endpoint
# AWS_BUG: if you set the path part ot 'test' it breaks!!
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  parent_id   = aws_api_gateway_rest_api.example_api.root_resource_id
  path_part   = var.api_path
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example_integration" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  # method that the api gateway will use to call the lambda - lambdas can only be invoked by POST, even though the gateway method may be a GET
  type                    = "AWS_PROXY"
  uri                     = var.lambda_json_invoke_arn
  integration_http_method = "POST"
}

resource "aws_lambda_permission" "apigateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_json_function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.example_api.id}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.example_integration]
  rest_api_id = aws_api_gateway_rest_api.example_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api_resource.id,
      aws_api_gateway_method.api_method.id,
      aws_api_gateway_integration.example_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  stage_name    = var.project_prefix
}

output "lambda_public_url" {
  value = "${aws_api_gateway_stage.api_stage.invoke_url}${aws_api_gateway_resource.api_resource.path_part}"
}
