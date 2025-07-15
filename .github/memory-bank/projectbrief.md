# Project Brief: Shared Cloud Infrastructure for Lambda Deployments

## Overview

This project creates a shared AWS infrastructure foundation that multiple Lambda development teams can reference and use for their deployments. The infrastructure provides the common resources needed for Lambda functions while keeping the actual Lambda code in separate repositories.

## Goals

- **Primary**: Create reusable Terraform infrastructure for Lambda deployments
- **Secondary**: Reduce cost and complexity by sharing common AWS resources
- **Tertiary**: Enable teams to deploy Lambda functions without infrastructure expertise

## Scope

### In Scope

- VPC with private/public subnets
- API Gateway (REST API) foundation
- IAM roles for Lambda execution and GitHub Actions
- S3 buckets for deployment artifacts
- Security groups and networking
- Basic monitoring infrastructure
- Terraform outputs for consumption by Lambda repositories

### Out of Scope

- Actual Lambda function code or deployment
- Multiple environments (dev/staging/prod)
- Advanced monitoring and alerting
- Production security hardening
- Cost optimization beyond basic shared resources

## Success Criteria

1. Infrastructure deploys successfully via GitHub Actions
2. Lambda teams can reference infrastructure via Terraform remote state
3. Clear documentation for Lambda integration
4. Cost-efficient shared resource model
5. GitHub OIDC authentication working

## Key Constraints

- POC scope - keep it simple
- Infrastructure only - no Lambda functions in this repo
- Single environment to start
- Focus on core functionality over advanced features

## Architecture Pattern

```
This Repo (cloud-infra) → Shared Infrastructure
    ↓ (remote state reference)
Lambda Repo 1 → Lambda Function A
Lambda Repo 2 → Lambda Function B
Lambda Repo 3 → Lambda Function C
```

## Technology Stack

- **Infrastructure**: Terraform
- **Cloud Provider**: AWS
- **CI/CD**: GitHub Actions
- **State Management**: Terraform remote state
- **Authentication**: GitHub OIDC
