# Example Lambda Integration

This directory contains a complete example of how to integrate a Lambda function with the shared cloud infrastructure.

> 🚀 **Quick Start**: Use our [Copier Template](../copier-template/) to automatically generate a new Lambda service with all the configurations below. Simply run:
>
> ```bash
> copier copy ./copier-template my-new-service
> ```
>
> This will create a complete, production-ready Lambda service in minutes!

## Manual Setup Guide

If you prefer to set up your Lambda service manually or want to understand the structure, follow this guide:

## Structure

```
example-lambda-service/
├── src/
│   ├── index.js             # Lambda function code
│   ├── package.json         # Node.js dependencies
│   └── package-lock.json    # Dependency lock file
├── terraform/
│   ├── main.tf              # Infrastructure definition
│   ├── variables.tf         # Configuration variables
│   ├── outputs.tf           # Resource outputs
│   └── versions.tf          # Provider requirements
├── .github/
│   └── workflows/
│       └── deploy.yml       # CI/CD pipeline
└── README.md                # Service documentation
```

## Lambda Function (src/index.js)

```javascript
exports.handler = async (event, context) => {
  console.log("Event:", JSON.stringify(event, null, 2));

  // API Gateway proxy integration
  if (event.httpMethod) {
    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        message: "Hello from shared infrastructure!",
        service: "example-service",
        method: event.httpMethod,
        path: event.path,
        timestamp: new Date().toISOString(),
      }),
    };
  }

  // Direct Lambda invocation
  return {
    message: "Hello from Lambda!",
    service: "example-service",
    timestamp: new Date().toISOString(),
  };
};
```

## Package.json

```json
{
  "name": "example-lambda-service",
  "version": "1.0.0",
  "description": "Example Lambda service using shared infrastructure",
  "main": "index.js",
  "scripts": {
    "test": "node index.js"
  },
  "dependencies": {},
  "devDependencies": {},
  "keywords": ["lambda", "aws", "shared-infrastructure"],
  "author": "Your Team",
  "license": "MIT"
}
```

## Terraform Configuration (terraform/main.tf)

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "lambda-services/example-service/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# Reference shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "shared-infra/terraform.tfstate"
    region = var.aws_region
  }
}

# Lambda function
resource "aws_lambda_function" "example_service" {
  function_name = "${var.service_name}-${var.environment}"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = 30
  memory_size   = 128

  # Use shared IAM role
  role = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn

  # Deploy in shared VPC
  vpc_config {
    subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
  }

  # Deploy from shared S3 bucket
  s3_bucket = data.terraform_remote_state.shared_infra.outputs.deployment_bucket_name
  s3_key    = "${var.service_name}/deployment-${var.deployment_version}.zip"

  environment {
    variables = {
      NODE_ENV        = var.environment
      SERVICE_NAME    = var.service_name
      API_GATEWAY_URL = data.terraform_remote_state.shared_infra.outputs.api_gateway_invoke_url
    }
  }

  tags = {
    Service     = var.service_name
    Environment = var.environment
    Team        = var.team_name
  }
}

# API Gateway resource
resource "aws_api_gateway_resource" "example_service" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  parent_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_root_resource_id
  path_part   = var.service_name
}

# API Gateway method
resource "aws_api_gateway_method" "example_service" {
  rest_api_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id   = aws_api_gateway_resource.example_service.id
  http_method   = "ANY"
  authorization = "NONE"
}

# API Gateway integration
resource "aws_api_gateway_integration" "example_service" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id = aws_api_gateway_resource.example_service.id
  http_method = aws_api_gateway_method.example_service.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.example_service.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.terraform_remote_state.shared_infra.outputs.api_gateway_execution_arn}/*/*"
}

# Trigger API Gateway deployment
resource "aws_api_gateway_deployment" "example_service" {
  depends_on = [
    aws_api_gateway_method.example_service,
    aws_api_gateway_integration.example_service,
  ]

  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  stage_name  = data.terraform_remote_state.shared_infra.outputs.api_gateway_stage_name

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.example_service.id,
      aws_api_gateway_method.example_service.id,
      aws_api_gateway_integration.example_service.id,
    ]))
  }
}
```

## Variables (terraform/variables.tf)

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name of the service"
  type        = string
  default     = "example-service"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "team_name" {
  description = "Team responsible for this service"
  type        = string
  default     = "platform"
}

variable "deployment_version" {
  description = "Version of the deployment package"
  type        = string
  default     = "latest"
}
```

## Outputs (terraform/outputs.tf)

```hcl
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.example_service.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.example_service.arn
}

output "api_endpoint" {
  description = "API Gateway endpoint for this service"
  value       = "${data.terraform_remote_state.shared_infra.outputs.api_gateway_invoke_url}/${var.service_name}"
}

output "service_info" {
  description = "Service information"
  value = {
    name        = var.service_name
    environment = var.environment
    endpoint    = "${data.terraform_remote_state.shared_infra.outputs.api_gateway_invoke_url}/${var.service_name}"
    function    = aws_lambda_function.example_service.function_name
  }
}
```

## GitHub Actions (.github/workflows/deploy.yml)

```yaml
name: Deploy Example Service

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to deploy to"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - staging
          - prod

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  SERVICE_NAME: example-service

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: |
          cd src
          npm ci --production

      - name: Run tests
        run: |
          cd src
          npm test

      - name: Package Lambda function
        run: |
          cd src
          zip -r ../deployment-${{ github.sha }}.zip .
          ls -la ../deployment-${{ github.sha }}.zip

      - name: Upload deployment package to S3
        run: |
          # Get the shared deployment bucket name
          BUCKET_NAME=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `shared-lambda-infra-deployments`)].Name' --output text)
          echo "Using bucket: $BUCKET_NAME"

          # Upload deployment package
          aws s3 cp deployment-${{ github.sha }}.zip \
            s3://$BUCKET_NAME/${{ env.SERVICE_NAME }}/deployment-${{ github.sha }}.zip

          echo "Uploaded deployment package to S3"

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.7"

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan \
            -var="deployment_version=${{ github.sha }}" \
            -var="environment=${{ github.event.inputs.environment || 'dev' }}"

      - name: Terraform Apply
        run: |
          cd terraform
          terraform apply -auto-approve \
            -var="deployment_version=${{ github.sha }}" \
            -var="environment=${{ github.event.inputs.environment || 'dev' }}"

      - name: Test API Endpoint
        run: |
          cd terraform
          API_ENDPOINT=$(terraform output -raw api_endpoint)
          echo "Testing endpoint: $API_ENDPOINT"

          # Wait a bit for deployment to be ready
          sleep 10

          # Test the endpoint
          curl -X GET "$API_ENDPOINT" \
            -H "Content-Type: application/json" \
            --retry 3 \
            --retry-delay 5

      - name: Display Deployment Info
        run: |
          cd terraform
          echo "## 🚀 Deployment Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Service:** ${{ env.SERVICE_NAME }}" >> $GITHUB_STEP_SUMMARY
          echo "**Environment:** ${{ github.event.inputs.environment || 'dev' }}" >> $GITHUB_STEP_SUMMARY
          echo "**Function:** $(terraform output -raw lambda_function_name)" >> $GITHUB_STEP_SUMMARY
          echo "**Endpoint:** $(terraform output -raw api_endpoint)" >> $GITHUB_STEP_SUMMARY
          echo "**Version:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
```

## Testing Your Deployment

### 1. Test Lambda Function Directly

```bash
aws lambda invoke \
  --function-name example-service-dev \
  --payload '{"test": "direct invocation"}' \
  response.json

cat response.json
```

### 2. Test via API Gateway

```bash
# Get the API endpoint
API_ENDPOINT="https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/api/example-service"

# Test GET request
curl -X GET $API_ENDPOINT

# Test POST request
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from API Gateway!"}'
```

### 3. Check CloudWatch Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/example-service-dev"

# Get recent logs
aws logs get-log-events \
  --log-group-name "/aws/lambda/example-service-dev" \
  --log-stream-name "$(aws logs describe-log-streams --log-group-name "/aws/lambda/example-service-dev" --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text)"
```

## Customization

### Add Environment-Specific Configuration

```hcl
# In variables.tf
variable "memory_size_by_env" {
  type = map(number)
  default = {
    dev     = 128
    staging = 256
    prod    = 512
  }
}

# In main.tf
resource "aws_lambda_function" "example_service" {
  memory_size = var.memory_size_by_env[var.environment]
  # ... other configuration
}
```

### Add Additional API Methods

```hcl
# Add specific resource for ID-based operations
resource "aws_api_gateway_resource" "example_service_item" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  parent_id   = aws_api_gateway_resource.example_service.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "example_service_get" {
  rest_api_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id   = aws_api_gateway_resource.example_service_item.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}
```

This example provides a complete, working Lambda service that integrates with the shared infrastructure. Use it as a template for your own services!
