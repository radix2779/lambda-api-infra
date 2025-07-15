# Lambda TypeScript Template

This Copier template creates a new TypeScript Lambda function that integrates with the shared cloud infrastructure.

## 🚀 Quick Start

### Prerequisites

- Python 3.8+ with `copier` installed: `pip install copier`
- Node.js 18+ for Lambda development
- AWS CLI configured
- Terraform installed

### Generate New Lambda Service

```bash
# Install copier if not already installed
pip install copier

# Generate a new Lambda service
copier copy https://github.com/your-org/cloud-infra.git --subdirectory=templates/lambda-typescript my-new-service

# Or if you have the repo locally
copier copy ./templates/lambda-typescript my-new-service
```

### Configuration Prompts

The template will ask you for:

| Field                       | Description                       | Example                                              |
| --------------------------- | --------------------------------- | ---------------------------------------------------- |
| `service_name`              | Lambda service name               | `user-service`                                       |
| `service_description`       | Brief description                 | `Manages user accounts and profiles`                 |
| `aws_region`                | AWS deployment region             | `us-east-1`                                          |
| `shared_infra_state_bucket` | S3 bucket with shared infra state | `my-terraform-state-bucket`                          |
| `github_org`                | GitHub organization               | `my-company`                                         |
| `github_repo`               | Repository name                   | `user-service`                                       |
| `aws_role_arn`              | GitHub Actions AWS role ARN       | `arn:aws:iam::123456789012:role/github-actions-role` |
| `lambda_memory`             | Memory allocation (MB)            | `256`                                                |
| `lambda_timeout`            | Timeout (seconds)                 | `30`                                                 |
| `enable_api_gateway`        | Create API Gateway integration    | `true`                                               |
| `api_path`                  | API Gateway path                  | `/users`                                             |
| `environment_variables`     | Comma-separated env vars          | `DATABASE_URL,API_KEY`                               |
| `include_tests`             | Include Jest testing              | `true`                                               |
| `include_eslint`            | Include ESLint                    | `true`                                               |
| `include_prettier`          | Include Prettier                  | `true`                                               |

## 📁 Generated Structure

```
my-new-service/
├── src/
│   └── index.ts              # Lambda handler with TypeScript
├── tests/
│   ├── setup.ts              # Test configuration
│   └── index.test.ts         # Unit tests
├── terraform/
│   ├── main.tf               # Infrastructure definition
│   ├── variables.tf          # Configuration variables
│   ├── outputs.tf            # Resource outputs
│   └── versions.tf           # Provider requirements
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
├── package.json              # Node.js dependencies
├── tsconfig.json             # TypeScript configuration
├── .eslintrc.js              # ESLint rules (optional)
├── .prettierrc               # Prettier config (optional)
├── jest.config.js            # Jest configuration (optional)
└── README.md                 # Service documentation
```

## 🔧 Development Workflow

### 1. Initial Setup

```bash
cd my-new-service

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests (if enabled)
npm test
```

### 2. Configure Terraform Backend

Edit `terraform/main.tf` and configure the S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "my-new-service/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
  }
}
```

### 3. Set Up GitHub Repository

1. Create a new GitHub repository
2. Push the generated code
3. Set up repository variables:

```bash
# GitHub repository variables
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-role
```

### 4. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 🎯 Template Features

### TypeScript Lambda Handler

The generated handler supports:

- **API Gateway Integration**: Full REST API support with proper routing
- **Direct Invocation**: Support for direct Lambda calls
- **Error Handling**: Structured error responses
- **CORS Support**: Pre-configured CORS headers
- **Type Safety**: Full TypeScript support with AWS Lambda types

### Infrastructure Integration

- **VPC Configuration**: Automatically uses shared private subnets
- **IAM Roles**: Uses shared Lambda execution role
- **API Gateway**: Integrates with shared API Gateway
- **CloudWatch**: Automatic log group creation
- **S3 Deployment**: Uses shared deployment bucket

### CI/CD Pipeline

- **GitHub Actions**: Automated build and deployment
- **Testing**: Runs unit tests and linting
- **TypeScript Build**: Compiles and packages code
- **Terraform**: Infrastructure deployment
- **Lambda Update**: Automatic function code updates

### Development Tools

- **TypeScript**: Full type checking and compilation
- **Jest**: Unit testing framework (optional)
- **ESLint**: Code linting with TypeScript rules (optional)
- **Prettier**: Code formatting (optional)

## 🔄 Updating Services

To update an existing service with template changes:

```bash
# Update with latest template
copier update

# Review and commit changes
git diff
git add .
git commit -m "Update from template"
```

## 🛠️ Customization

### Adding Dependencies

```bash
# Production dependencies
npm install axios

# Development dependencies
npm install --save-dev @types/axios
```

### Environment Variables

1. Add to `terraform/variables.tf`:

```hcl
variable "database_url" {
  description = "Database connection string"
  type        = string
  sensitive   = true
}
```

2. Update `terraform/main.tf`:

```hcl
environment {
  variables = {
    DATABASE_URL = var.database_url
  }
}
```

3. Set in GitHub repository secrets or Terraform

### API Gateway Customization

The template creates a basic proxy integration. For custom API Gateway configurations, modify:

- `terraform/main.tf` - API Gateway resources
- `src/index.ts` - Request/response handling

## 🆘 Troubleshooting

### Common Issues

1. **TypeScript Build Errors**

   ```bash
   npm run build
   # Check for type errors
   ```

2. **Terraform State Issues**

   ```bash
   terraform init -reconfigure
   ```

3. **GitHub Actions Failures**

   - Verify AWS_ROLE_ARN is set correctly
   - Check AWS permissions for the role

4. **Lambda Runtime Errors**
   ```bash
   # Check CloudWatch logs
   aws logs tail /aws/lambda/my-service --follow
   ```

### Getting Help

- Check the [shared infrastructure docs](../docs/)
- Review existing Lambda examples
- Create an issue in the infrastructure repository

## 📚 Examples

### Basic API Handler

```typescript
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  const { httpMethod, pathParameters } = event;

  switch (httpMethod) {
    case "GET":
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: "Hello World!" }),
      };
    default:
      return {
        statusCode: 405,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Method not allowed" }),
      };
  }
};
```

### Database Integration

```typescript
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const dynamodb = new DynamoDBClient({ region: process.env.AWS_REGION });

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Your database logic here
};
```

---

Need help or have questions? Check the main [cloud infrastructure documentation](../../README.md) or create an issue.
