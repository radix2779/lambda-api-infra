# Product Context: Shared Lambda Infrastructure Platform

## Problem Statement

Development teams need to deploy Lambda functions but don't want to manage individual VPCs, API Gateways, and supporting infrastructure for each project. This leads to:

- Duplicated infrastructure costs
- Inconsistent networking and security setups
- Teams spending time on infrastructure instead of application logic
- Lack of standardization across Lambda deployments

## Solution

A shared infrastructure platform that provides common AWS resources for Lambda function deployments. Teams can focus on their Lambda code while leveraging standardized, cost-effective infrastructure.

## Target Users

- **Primary**: Development teams deploying Lambda functions
- **Secondary**: DevOps teams managing infrastructure
- **Tertiary**: Engineering leadership looking for cost optimization

## User Experience Goals

### For Lambda Development Teams

- Reference shared infrastructure with simple Terraform data sources
- Deploy Lambda functions without infrastructure expertise
- Get consistent networking and security by default
- Access to shared API Gateway for REST endpoints

### For Platform Team

- Centralized infrastructure management
- Cost visibility and optimization
- Standardized security and networking policies
- Easy onboarding process for new teams

## Key Use Cases

1. **New Lambda Function**: Team creates new repo, references shared infra, deploys function
2. **API Gateway Integration**: Team adds their Lambda to the shared API Gateway
3. **Infrastructure Updates**: Platform team updates shared resources, all Lambda functions benefit
4. **Cost Monitoring**: Single place to monitor infrastructure costs across all Lambda functions

## Business Value

- **Cost Reduction**: Shared NAT Gateways, VPC, API Gateway
- **Faster Time to Market**: Teams deploy faster without infrastructure setup
- **Consistency**: Standardized patterns across all Lambda deployments
- **Reduced Complexity**: Infrastructure expertise centralized to platform team

## Non-Goals

- Managing Lambda function source code
- Providing development environments
- Complex multi-tenant security isolation
- Advanced CI/CD orchestration beyond basic infrastructure deployment
