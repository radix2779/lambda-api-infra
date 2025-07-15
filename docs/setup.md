# Setup Guide: Shared Cloud Infrastructure

This guide walks you through setting up the shared cloud infrastructure for Lambda deployments from scratch.

## Prerequisites

### Required Tools

- **AWS CLI** v2.x installed and configured
- **Terraform** v1.5+ installed
- **Git** for repository management
- **GitHub account** with Actions enabled

### AWS Permissions

Your AWS user/role needs these permissions:

- VPC management (create VPC, subnets, gateways)
- IAM management (create roles, policies)
- API Gateway management
- S3 bucket management
- CloudWatch logs management
- (Optional) Route53 for custom domains

## Step 1: AWS Account Preparation

### 1.1 Create Terraform State Resources

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket-name --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket-name \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 1.2 Set up GitHub OIDC (Optional but Recommended)

If you want to use GitHub OIDC instead of access keys:

```bash
# This will be created automatically by Terraform, but you can pre-create it
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

## Step 2: Repository Setup

### 2.1 Clone/Fork Repository

```bash
# Clone this repository
git clone <repository-url>
cd cloud-infra

# Or fork it on GitHub and clone your fork
```

### 2.2 Configure Terraform Backend

Edit `terraform/versions.tf` and uncomment the backend configuration:

```hcl
terraform {
  # Uncomment and configure this block
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"
    key            = "shared-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

### 2.3 Customize Configuration (Optional)

Edit `terraform/variables.tf` to customize your setup:

```hcl
variable "project_name" {
  default = "your-company-lambda-infra"  # Change this
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"  # Change if needed
}

variable "github_repositories" {
  default = [
    "your-org/lambda-repo-1",
    "your-org/lambda-repo-2"
  ]  # Add your Lambda repositories
}
```

## Step 3: GitHub Configuration

### 3.1 Set Repository Variables

In your GitHub repository settings → Secrets and variables → Actions → Variables:

| Variable Name         | Value                              | Description                      |
| --------------------- | ---------------------------------- | -------------------------------- |
| `AWS_REGION`          | `us-east-1`                        | AWS region for deployment        |
| `TF_STATE_BUCKET`     | `your-terraform-state-bucket-name` | S3 bucket for Terraform state    |
| `TF_STATE_LOCK_TABLE` | `terraform-state-locks`            | DynamoDB table for state locking |

### 3.2 Set Repository Secrets

In GitHub repository settings → Secrets and variables → Actions → Secrets:

**Option A: Using AWS Access Keys**
| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | `...` | AWS secret access key |

**Option B: Using GitHub OIDC (Recommended)**
| Variable Name | Value | Description |
|---------------|-------|-------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-role` | IAM role for GitHub Actions |

> **Note**: If using OIDC, you'll need to create the role first or run a bootstrap deployment with access keys, then switch to OIDC.

## Step 4: Bootstrap Deployment

### 4.1 Initial Deployment with Access Keys

If using access keys for initial setup:

1. **Test Locally (Optional)**:

   ```bash
   cd terraform

   # Initialize
   terraform init

   # Plan to see what will be created
   terraform plan \
     -var="github_repositories=[\"your-org/your-repo\"]"

   # Apply if plan looks good
   terraform apply \
     -var="github_repositories=[\"your-org/your-repo\"]"
   ```

2. **Deploy via GitHub Actions**:
   ```bash
   # Commit your configuration changes
   git add .
   git commit -m "Configure infrastructure for our organization"
   git push origin main
   ```

### 4.2 Switch to OIDC (If Desired)

After initial deployment, update your GitHub workflow to use OIDC:

1. Get the GitHub Actions role ARN from Terraform outputs:

   ```bash
   terraform output github_actions_role_arn
   ```

2. Update GitHub repository variables with the role ARN
3. Remove AWS access key secrets
4. Push a change to trigger the workflow with OIDC

## Step 5: Verify Deployment

### 5.1 Check Infrastructure Outputs

```bash
cd terraform
terraform output
```

You should see outputs like:

```
api_gateway_invoke_url = "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/api"
deployment_bucket_name = "shared-lambda-infra-deployments-xxxxxxxxxx"
lambda_execution_role_arn = "arn:aws:iam::123456789012:role/shared-lambda-infra-lambda-execution-xxxxxxxxxx"
vpc_id = "vpc-xxxxxxxxxx"
```

### 5.2 Test API Gateway

```bash
# Test the API Gateway endpoint
API_URL=$(terraform output -raw api_gateway_invoke_url)
curl $API_URL

# Should return a 403 (no resources defined yet - this is expected)
```

### 5.3 Verify S3 Bucket

```bash
# Check the deployment bucket exists
BUCKET=$(terraform output -raw deployment_bucket_name)
aws s3 ls s3://$BUCKET
```

## Step 6: Create Your First Lambda

### 6.1 Create Lambda Repository

Create a new repository for your Lambda function using the pattern from the [Lambda Integration Guide](docs/lambda-integration.md).

### 6.2 Reference Shared Infrastructure

In your Lambda repository's `terraform/main.tf`:

```hcl
data "terraform_remote_state" "shared_infra" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket-name"  # Same as infrastructure
    key    = "shared-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use the shared infrastructure outputs
resource "aws_lambda_function" "my_function" {
  # ... your Lambda configuration
  role = data.terraform_remote_state.shared_infra.outputs.lambda_execution_role_arn

  vpc_config {
    subnet_ids         = data.terraform_remote_state.shared_infra.outputs.private_subnet_ids
    security_group_ids = [data.terraform_remote_state.shared_infra.outputs.lambda_security_group_id]
  }
}
```

## Troubleshooting

### Common Issues

**1. Terraform Init Fails**

```
Error: Failed to get existing workspaces
```

**Solution**: Check S3 bucket name and permissions. Ensure bucket exists and is accessible.

**2. GitHub Actions Permission Denied**

```
Error: operation error STS: AssumeRoleWithWebIdentity
```

**Solution**:

- Verify AWS_ROLE_ARN variable is set correctly
- Check IAM role trust policy includes your repository
- Ensure repository name format is `owner/repo`

**3. VPC Resource Limits**

```
Error: VpcLimitExceeded
```

**Solution**: Check your AWS account VPC limits. Default is 5 VPCs per region.

**4. API Gateway Deployment Issues**

```
Error: creating API Gateway Deployment
```

**Solution**: This is usually due to no resources/methods defined. This is expected for the base infrastructure.

### Getting Help

1. **Check CloudWatch Logs**: Look at deployment logs in CloudWatch
2. **Verify Permissions**: Ensure your IAM user/role has required permissions
3. **Test Locally**: Run `terraform plan` locally to debug issues
4. **Check AWS Limits**: Verify you haven't hit service limits

## Next Steps

1. **Deploy a Lambda Function**: Follow the [Lambda Integration Guide](docs/lambda-integration.md)
2. **Set Up Monitoring**: Configure CloudWatch alarms and dashboards
3. **Add Custom Domains**: Set up Route53 and ACM certificates for API Gateway
4. **Scale Up**: Add more Lambda functions using the same infrastructure
5. **Optimize Costs**: Review AWS Cost Explorer and set up billing alerts

## Security Best Practices

- ✅ Use GitHub OIDC instead of long-lived access keys
- ✅ Enable S3 bucket versioning and encryption
- ✅ Use least-privilege IAM policies
- ✅ Enable CloudTrail for audit logging
- ✅ Regularly review and rotate credentials
- ✅ Use AWS Config for compliance monitoring

## Cost Optimization

- **Monitor Usage**: Set up AWS Cost Explorer and billing alerts
- **Right-Size Resources**: Adjust Lambda memory and timeout based on usage
- **Use Reserved Capacity**: Consider reserved capacity for predictable workloads
- **Clean Up**: Regularly clean up old Lambda deployment packages
- **VPC Endpoints**: Consider adding more VPC endpoints to reduce NAT Gateway costs

---

**Congratulations!** 🎉 You now have a shared cloud infrastructure that your teams can use to deploy Lambda functions efficiently and cost-effectively.
