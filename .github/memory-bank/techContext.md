# Technical Context: Infrastructure Foundation

## Technology Stack

### Infrastructure as Code

- **Primary Tool**: Terraform 1.5+
- **Provider**: AWS Provider 5.x
- **State Backend**: S3 with DynamoDB locking
- **Validation**: terraform fmt, validate, and plan

### AWS Services

- **Compute Foundation**: VPC, Subnets, Security Groups
- **API Layer**: API Gateway (REST API)
- **Identity & Access**: IAM roles and policies
- **Storage**: S3 buckets for artifacts and state
- **Monitoring**: CloudWatch Logs and basic metrics
- **Networking**: Internet Gateway, NAT Gateway, Route Tables

### CI/CD Platform

- **Primary**: GitHub Actions
- **Authentication**: GitHub OIDC (no long-lived keys)
- **Workflow Triggers**: Push to main, manual dispatch
- **Artifacts**: Terraform outputs stored as GitHub artifacts

## Development Setup

### Prerequisites

- AWS CLI configured
- Terraform 1.5+ installed
- GitHub CLI (optional)
- Access to target AWS account

### Local Development

```bash
# Clone repository
git clone <repository-url>
cd cloud-infra

# Initialize Terraform
cd terraform
terraform init

# Plan changes
terraform plan

# Apply changes (use GitHub Actions for actual deployment)
terraform apply
```

### GitHub Repository Setup

1. Configure GitHub OIDC identity provider in AWS
2. Set repository secrets/variables:
   - `AWS_ROLE_ARN`: GitHub Actions deployment role
   - `AWS_REGION`: Target AWS region
   - `TF_STATE_BUCKET`: Terraform state bucket name
3. Enable GitHub Actions workflows

## Technical Constraints

### AWS Limits

- **VPC Limits**: 5 VPCs per region (default)
- **Lambda Limits**: 1000 concurrent executions (default)
- **API Gateway**: 10,000 requests per second (default)
- **IAM**: 5,120 characters per policy document

### Cost Considerations

- **NAT Gateway**: $45/month + data processing charges
- **API Gateway**: $3.50 per million requests
- **VPC Endpoints**: $0.01/hour per endpoint
- **CloudWatch Logs**: $0.50 per GB ingested

### Security Requirements

- **Networking**: Lambda functions in private subnets
- **IAM**: Least privilege access policies
- **Encryption**: S3 buckets encrypted at rest
- **Access**: GitHub OIDC for deployment authentication

## File Structure

```
terraform/
├── main.tf              # Core infrastructure resources
├── variables.tf         # Input configuration
├── outputs.tf          # Exports for Lambda repos
├── versions.tf         # Provider and version constraints
└── terraform.tf       # Backend configuration
```

## Dependencies

### Terraform Modules

- No external modules (keep it simple for POC)
- All resources defined directly in main.tf

### AWS Services Dependencies

- VPC → Subnets → Route Tables → NAT Gateway
- IAM → Roles → Policies
- API Gateway → Deployment → Stage
- S3 → Bucket → Lifecycle → Versioning

## Configuration Management

### Variables

- **Required**: aws_region, project_name
- **Optional**: vpc_cidr, availability_zones
- **Computed**: resource names, ARNs, IDs

### Outputs

- **Network**: VPC ID, subnet IDs, security group IDs
- **API**: API Gateway ID, execution ARN, invoke URL
- **IAM**: Role ARNs for Lambda execution and GitHub Actions
- **Storage**: S3 bucket names and ARNs

## Monitoring & Observability

### Built-in Monitoring

- CloudWatch Log Groups for Lambda functions
- VPC Flow Logs for network monitoring
- API Gateway access logs
- Basic CloudWatch dashboards

### Health Checks

- Terraform state consistency
- Resource deployment status
- GitHub Actions workflow status
- AWS service quotas monitoring
