#------------------------------------------------------------------------------
# Network Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets for Lambda deployment"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

#------------------------------------------------------------------------------
# API Gateway Outputs
#------------------------------------------------------------------------------

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID of the API Gateway"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway for Lambda permissions"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${local.region}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

#------------------------------------------------------------------------------
# IAM Outputs
#------------------------------------------------------------------------------

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deployment role"
  value       = length(aws_iam_role.github_actions) > 0 ? aws_iam_role.github_actions[0].arn : null
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions deployment role"
  value       = length(aws_iam_role.github_actions) > 0 ? aws_iam_role.github_actions[0].name : null
}

#------------------------------------------------------------------------------
# Storage Outputs
#------------------------------------------------------------------------------

output "deployment_bucket_name" {
  description = "Name of the S3 bucket for Lambda deployment packages"
  value       = aws_s3_bucket.deployments.bucket
}

output "deployment_bucket_arn" {
  description = "ARN of the S3 bucket for Lambda deployment packages"
  value       = aws_s3_bucket.deployments.arn
}

output "deployment_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.deployments.bucket_domain_name
}

#------------------------------------------------------------------------------
# Monitoring Outputs
#------------------------------------------------------------------------------

output "api_gateway_log_group_name" {
  description = "CloudWatch log group name for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "lambda_log_group_prefix" {
  description = "CloudWatch log group prefix for Lambda functions"
  value       = "/aws/lambda"
}

#------------------------------------------------------------------------------
# General Outputs
#------------------------------------------------------------------------------

output "aws_region" {
  description = "AWS region"
  value       = local.region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = local.account_id
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

#------------------------------------------------------------------------------
# Integration Examples
#------------------------------------------------------------------------------

output "lambda_integration_example" {
  description = "Example Terraform configuration for Lambda integration"
  value       = <<-EOT
# Example: How to reference this shared infrastructure in a Lambda repository

data "terraform_remote_state" "shared_infra" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "shared-infra/terraform.tfstate"
    region = "${local.region}"
  }
}

resource "aws_lambda_function" "example" {
  function_name = "my-function"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  role          = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn
  
  vpc_config {
    subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
  }
  
  # Deploy from shared S3 bucket
  s3_bucket = data.terraform_remote_state.shared_infra.outputs.deployment_bucket_name
  s3_key    = "my-function/deployment.zip"
}

# API Gateway Integration
resource "aws_api_gateway_resource" "example" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  parent_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_root_resource_id
  path_part   = "my-function"
}

resource "aws_api_gateway_method" "example" {
  rest_api_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id = aws_api_gateway_resource.example.id
  http_method = aws_api_gateway_method.example.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.example.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"
  # Note: Replace with your actual API Gateway execution ARN output
  source_arn    = "arn:aws:execute-api:REGION:ACCOUNT_ID:API_GATEWAY_ID/*/*"
}
EOT
}
