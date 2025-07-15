# Shared Cloud Infrastructure for Lambda Deployments

This repository provides shared AWS infrastructure that Lambda development teams can reference and use for their deployments. It creates a cost-effective, standardized foundation for Lambda functions.

## 🏗️ What This Creates

### Core Infrastructure

- **VPC** with private and public subnets across multiple AZs
- **API Gateway** (REST API) ready for Lambda integrations
- **IAM Roles** for Lambda execution and GitHub Actions deployment
- **S3 Bucket** for Lambda deployment packages
- **Security Groups** configured for Lambda functions
- **CloudWatch** log groups for monitoring

### Key Benefits

- **Cost Efficient**: Shared NAT Gateway and VPC across all Lambda functions
- **Standardized**: Consistent networking and security for all deployments
- **Ready to Use**: Teams can deploy Lambda functions immediately
- **Secure**: GitHub OIDC integration, no long-lived AWS credentials

## 🚀 Quick Start

### 1. Deploy the Infrastructure

**Prerequisites:**

- AWS account with appropriate permissions
- GitHub repository with Actions enabled
- S3 bucket for Terraform state (optional but recommended)

**Repository Variables to Set:**

```bash
AWS_ROLE_ARN=arn:aws:iam::YOUR-ACCOUNT:role/github-actions-role
TF_STATE_BUCKET=your-terraform-state-bucket
TF_STATE_LOCK_TABLE=terraform-state-locks
```

**Deploy:**

1. Fork/clone this repository
2. Set the required GitHub repository variables
3. Push to `main` branch or manually trigger the workflow
4. Infrastructure will be deployed automatically

### 2. Use in Your Lambda Project

**Option A: Use the Copier Template (Recommended)**

Generate a new TypeScript Lambda service instantly:

```bash
# Install copier
pip install copier

# Generate new Lambda service
copier copy https://github.com/your-org/cloud-infra.git --subdirectory=templates/lambda-typescript my-new-service

# Follow the prompts to configure your service
cd my-new-service
npm install
npm run build
```

**Option B: Manual Integration**

In your Lambda function repository, reference the shared infrastructure:

```hcl
# main.tf in your Lambda repository
data "terraform_remote_state" "shared_infra" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "shared-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_lambda_function" "my_function" {
  function_name = "my-awesome-function"
  runtime       = "nodejs20.x"
  handler       = "index.handler"

  # Use shared infrastructure
  role = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn

  vpc_config {
    subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
  }

  # Your function-specific configuration
  s3_bucket = data.terraform_remote_state.shared_infra.outputs.deployment_bucket_name
  s3_key    = "my-function/deployment.zip"
}
```

## 📋 Available Outputs

The infrastructure provides these outputs for your Lambda functions:

### Network

- `vpc_id` - VPC ID for reference
- `private_subnet_ids` - Subnet IDs for Lambda deployment
- `lambda_security_group_id` - Security group for Lambda functions

### API Gateway

- `api_gateway_id` - REST API ID for Lambda integration
- `api_gateway_root_resource_id` - Root resource for creating endpoints
- `api_gateway_invoke_url` - Base URL for API calls
- `api_gateway_execution_arn` - For Lambda permissions

### IAM

- `lambda_execution_role_arn` - Pre-configured Lambda execution role
- `github_actions_role_arn` - Role for GitHub Actions deployment

### Storage

- `deployment_bucket_name` - S3 bucket for your Lambda packages
- `deployment_bucket_arn` - Bucket ARN for permissions

## 🔧 Configuration

### Environment Variables

You can customize the infrastructure by modifying `terraform/variables.tf`:

```hcl
# Example customization
variable "vpc_cidr" {
  default = "10.0.0.0/16"  # Change VPC CIDR
}

variable "enable_nat_gateway" {
  default = true  # Disable for cost savings (Lambda won't have internet)
}

variable "github_repositories" {
  default = ["your-org/lambda-repo-1", "your-org/lambda-repo-2"]
}
```

## 🛡️ Security

### GitHub OIDC Setup

The infrastructure sets up GitHub OIDC automatically. To use it:

1. The GitHub Actions role is created with repository-specific trust policy
2. No AWS credentials needed in GitHub secrets
3. Use the `aws-actions/configure-aws-credentials` action in your workflows

### Lambda Security

- Lambda functions deployed in private subnets
- Security group allows outbound traffic only
- IAM role follows least privilege principle
- S3 bucket has public access blocked

## 📊 Monitoring

### CloudWatch Integration

- API Gateway logs enabled
- Lambda log groups pre-created
- Basic monitoring included

### Cost Monitoring

- Shared resources reduce per-function costs
- Monitor usage through AWS Cost Explorer
- Set up billing alerts for your account

## 🔄 CI/CD Integration

### For This Infrastructure Repository

- Automatic deployment on push to main
- Terraform plan comments on pull requests
- Manual destroy option via workflow dispatch

### For Lambda Repositories

Use this pattern in your Lambda repository's GitHub Actions:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: us-east-1

- name: Deploy Lambda
  run: |
    # Build your Lambda package
    zip deployment.zip index.js

    # Upload to shared S3 bucket
    aws s3 cp deployment.zip s3://$(terraform output -raw deployment_bucket_name)/my-function/

    # Deploy with Terraform
    terraform apply -auto-approve
```

## 📖 Examples

### Lambda Service Template

Use the Copier template to generate new Lambda services:

```bash
copier copy ./templates/lambda-typescript my-service
```

See the [template documentation](templates/lambda-typescript/README.md) for detailed usage.

### Manual Integration Example

See the complete integration example in the Terraform outputs:

```bash
terraform output lambda_integration_example
```

## 🆘 Troubleshooting

### Common Issues

**1. GitHub Actions Permission Denied**

- Ensure AWS_ROLE_ARN is correctly set in repository variables
- Verify the role trust policy includes your repository

**2. Terraform State Conflicts**

- Use different state keys for different environments
- Ensure DynamoDB table exists for state locking

**3. Lambda Deployment Fails**

- Check VPC configuration and subnet availability
- Verify security group allows required traffic

**4. API Gateway Integration Issues**

- Ensure Lambda permissions are set correctly
- Check API Gateway deployment and stage configuration

## 🎯 Next Steps

1. **Deploy the infrastructure** using the GitHub Actions workflow
2. **Create your first Lambda function** using the integration examples
3. **Set up monitoring** and alerting for your specific needs
4. **Scale up** by adding more Lambda functions using the same infrastructure

## 💡 Contributing

1. Create feature branch from main
2. Make changes to Terraform files
3. Submit pull request (plan will be automatically generated)
4. Merge to main to deploy changes

---

**Need Help?** Check the documentation in the `docs/` folder or create an issue in this repository.
