# Lambda Integration Guide

This guide shows how to integrate your Lambda functions with the shared cloud infrastructure. The infrastructure provides all the foundational AWS resources your Lambda functions need.

## 🚀 Quick Start Options

### Option 1: Copier Template (Recommended)

The fastest way to create a new Lambda service is using our TypeScript template:

```bash
# Install copier
pip install copier

# Generate new Lambda service
copier copy https://github.com/your-org/cloud-infra.git --subdirectory=templates/lambda-typescript my-service

# Configure during generation
cd my-service
npm install
npm run build
```

This creates a complete TypeScript Lambda service with:

- ✅ Shared infrastructure integration
- ✅ GitHub Actions CI/CD
- ✅ TypeScript setup with proper types
- ✅ Jest testing framework
- ✅ ESLint and Prettier
- ✅ API Gateway integration

See the [template documentation](../templates/lambda-typescript/README.md) for detailed usage.

### Option 2: Manual Integration

For existing projects or custom setups, follow the manual integration steps below.

## Manual Integration

### 1. Reference Shared Infrastructure

Add this to your Lambda repository's Terraform configuration:

```hcl
# Data source to access shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "shared-infra/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 2. Deploy Your Lambda Function

```hcl
resource "aws_lambda_function" "my_function" {
  function_name = "my-service-function"
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
  s3_key    = "my-service/deployment-${var.deployment_version}.zip"

  # Environment variables
  environment {
    variables = {
      NODE_ENV = "production"
      API_GATEWAY_URL = data.terraform_remote_state.shared_infra.outputs.api_gateway_invoke_url
    }
  }

  tags = {
    Service = "my-service"
    Team    = "backend"
  }
}
```

### 3. Integrate with API Gateway

```hcl
# Create API Gateway resource
resource "aws_api_gateway_resource" "my_service" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  parent_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_root_resource_id
  path_part   = "my-service"
}

# Create method
resource "aws_api_gateway_method" "my_service_post" {
  rest_api_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id   = aws_api_gateway_resource.my_service.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Content-Type" = false
  }
}

# Create integration
resource "aws_api_gateway_integration" "my_service" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  resource_id = aws_api_gateway_resource.my_service.id
  http_method = aws_api_gateway_method.my_service_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.my_function.invoke_arn
}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.terraform_remote_state.shared_infra.outputs.api_gateway_execution_arn}/*/*"
}

# Trigger API Gateway deployment
resource "aws_api_gateway_deployment" "my_service" {
  depends_on = [
    aws_api_gateway_method.my_service_post,
    aws_api_gateway_integration.my_service,
  ]

  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  stage_name  = data.terraform_remote_state.shared_infra.outputs.api_gateway_stage_name

  # Force redeployment when integration changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.my_service.id,
      aws_api_gateway_method.my_service_post.id,
      aws_api_gateway_integration.my_service.id,
    ]))
  }
}
```

## Available Infrastructure Outputs

### Network Resources

```hcl
# VPC Configuration
vpc_id                    = "vpc-xxxxxxxxxxxx"
private_subnet_ids        = ["subnet-xxxxxxxxxxxx", "subnet-yyyyyyyyyyyy"]
lambda_security_group_id  = "sg-xxxxxxxxxxxx"

# Usage in Lambda
vpc_config {
  subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
  security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
}
```

### API Gateway Resources

```hcl
# API Gateway Configuration
api_gateway_id              = "xxxxxxxxxxxx"
api_gateway_root_resource_id = "xxxxxxxxxxxx"
api_gateway_execution_arn    = "arn:aws:execute-api:us-east-1:123456789012:xxxxxxxxxxxx"
api_gateway_invoke_url       = "https://xxxxxxxxxxxx.execute-api.us-east-1.amazonaws.com/api"

# Usage for creating resources
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  parent_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_root_resource_id
  path_part   = "my-endpoint"
}
```

### IAM Resources

```hcl
# IAM Configuration
lambda_execution_role_arn = "arn:aws:iam::123456789012:role/shared-lambda-infra-lambda-execution-xxxxxxxxxxxx"

# Usage in Lambda
resource "aws_lambda_function" "example" {
  role = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn
  # ... other configuration
}
```

### Storage Resources

```hcl
# S3 Configuration
deployment_bucket_name = "shared-lambda-infra-deployments-xxxxxxxxxxxx"

# Usage for deployment
s3_bucket = data.terraform_remote_state.shared_infra.outputs.deployment_bucket_name
s3_key    = "my-function/deployment.zip"
```

## Complete Example Repository Structure

```
my-lambda-service/
├── src/
│   ├── index.js                 # Lambda function code
│   ├── package.json             # Dependencies
│   └── ...
├── terraform/
│   ├── main.tf                  # Infrastructure definition
│   ├── variables.tf             # Configuration variables
│   ├── outputs.tf               # Outputs for reference
│   └── versions.tf              # Provider requirements
├── .github/
│   └── workflows/
│       └── deploy.yml           # CI/CD pipeline
├── tests/
│   └── ...                      # Function tests
└── README.md
```

### Example terraform/main.tf

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
    key    = "lambda-services/my-service/terraform.tfstate"
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
resource "aws_lambda_function" "my_service" {
  function_name = "${var.service_name}-${var.environment}"
  runtime       = var.lambda_runtime
  handler       = "index.handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  role = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn

  vpc_config {
    subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
  }

  s3_bucket = data.terraform_remote_state.shared_infra.outputs.deployment_bucket_name
  s3_key    = "${var.service_name}/deployment-${var.deployment_version}.zip"

  environment {
    variables = merge(
      {
        NODE_ENV = var.environment
        SERVICE_NAME = var.service_name
      },
      var.environment_variables
    )
  }

  tags = {
    Service     = var.service_name
    Environment = var.environment
    Team        = var.team_name
  }
}

# API Gateway integration
module "api_integration" {
  source = "./modules/api-integration"

  api_gateway_id      = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  api_root_resource   = data.terraform_remote_state.shared_infra.outputs.api_gateway_root_resource_id
  api_execution_arn   = data.terraform_remote_state.shared_infra.outputs.api_gateway_execution_arn
  lambda_function_arn = aws_lambda_function.my_service.arn
  lambda_function_name = aws_lambda_function.my_service.function_name

  service_name = var.service_name
  api_methods  = var.api_methods
}
```

### Example .github/workflows/deploy.yml

```yaml
name: Deploy Lambda Service

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  SERVICE_NAME: my-service

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

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

      - name: Package Lambda
        run: |
          cd src
          zip -r ../deployment-${{ github.sha }}.zip .

      - name: Upload to S3
        run: |
          # Get deployment bucket from shared infrastructure
          BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `shared-lambda-infra-deployments`)].Name' --output text)
          aws s3 cp deployment-${{ github.sha }}.zip s3://$BUCKET/${{ env.SERVICE_NAME }}/

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Deploy Infrastructure
        run: |
          cd terraform
          terraform init
          terraform plan -var="deployment_version=${{ github.sha }}"
          terraform apply -auto-approve -var="deployment_version=${{ github.sha }}"
```

## Testing Your Integration

### 1. Verify Lambda Function

```bash
# Test Lambda function directly
aws lambda invoke \
  --function-name my-service-function \
  --payload '{"test": "data"}' \
  response.json

cat response.json
```

### 2. Test API Gateway Integration

```bash
# Get API Gateway URL
API_URL=$(terraform output -raw api_gateway_invoke_url)

# Test your endpoint
curl -X POST "${API_URL}/my-service" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### 3. Check CloudWatch Logs

```bash
# View Lambda logs
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/my-service-function"

aws logs get-log-events \
  --log-group-name "/aws/lambda/my-service-function" \
  --log-stream-name "2024/01/15/[\$LATEST]..."
```

## Best Practices

### 1. Resource Naming

```hcl
# Use consistent naming convention
function_name = "${var.service_name}-${var.environment}"

# Tag resources properly
tags = {
  Service     = var.service_name
  Environment = var.environment
  Team        = var.team_name
  Repository  = "${var.github_org}/${var.github_repo}"
}
```

### 2. Environment Variables

```hcl
environment {
  variables = {
    NODE_ENV     = var.environment
    SERVICE_NAME = var.service_name
    API_BASE_URL = data.terraform_remote_state.shared_infra.outputs.api_gateway_invoke_url

    # Use AWS Systems Manager for secrets
    DB_CONNECTION_SECRET = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-service-db"
  }
}
```

### 3. API Gateway Patterns

```hcl
# RESTful resource structure
resource "aws_api_gateway_resource" "service" {
  path_part = "my-service"  # /api/my-service
}

resource "aws_api_gateway_resource" "service_id" {
  parent_id = aws_api_gateway_resource.service.id
  path_part = "{id}"  # /api/my-service/{id}
}

# Support multiple HTTP methods
resource "aws_api_gateway_method" "service_any" {
  http_method = "ANY"  # Supports GET, POST, PUT, DELETE, etc.
  authorization = "NONE"
}
```

### 4. Error Handling

```hcl
# Custom error responses
resource "aws_api_gateway_gateway_response" "my_service_4xx" {
  rest_api_id   = data.terraform_remote_state.shared_infra.outputs.api_gateway_id
  response_type = "DEFAULT_4XX"

  response_templates = {
    "application/json" = jsonencode({
      error   = "$context.error.message"
      service = "my-service"
    })
  }
}
```

This integration guide provides everything you need to deploy Lambda functions using the shared infrastructure. Start with the quick integration example and customize based on your specific requirements.
