variable "lambda_filename" {}
variable "lambda_json_hash" {}
variable "project_prefix" {}

resource "aws_iam_role" "lambda" {
  name = "${var.project_prefix}-iam-role-tf"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [ "lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# https://www.terraform.io/docs/providers/aws/r/lambda_function.html
resource "aws_lambda_function" "lambda_function" {
  function_name    = var.project_prefix
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = var.lambda_filename
  source_code_hash = var.lambda_json_hash

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# lambda logging
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days = 3
}

# OUTPUTS

output "lambda_json_invoke_arn" {
  value = aws_lambda_function.lambda_function.invoke_arn
}
output "lambda_json_function_name" {
  value = aws_lambda_function.lambda_function.function_name
}

output "lambda_json_qualified_arn" {
  value = aws_lambda_function.lambda_function.qualified_arn
}
