# Architecture Overview

## System Architecture

The shared cloud infrastructure follows a hub-and-spoke model where common AWS resources are centrally managed and consumed by distributed Lambda function repositories.

```mermaid
graph TB
    subgraph "Shared Infrastructure Repository"
        subgraph "AWS Account"
            VPC[VPC<br/>10.0.0.0/16]

            subgraph "Public Subnets"
                PUB1[Public Subnet 1<br/>10.0.101.0/24]
                PUB2[Public Subnet 2<br/>10.0.102.0/24]
                NAT[NAT Gateway]
            end

            subgraph "Private Subnets"
                PRIV1[Private Subnet 1<br/>10.0.1.0/24]
                PRIV2[Private Subnet 2<br/>10.0.2.0/24]
            end

            subgraph "Shared Services"
                API[API Gateway<br/>REST API]
                S3[S3 Bucket<br/>Deployments]
                IAM[IAM Roles]
                CW[CloudWatch<br/>Logs]
            end
        end
    end

    subgraph "Lambda Repositories"
        REPO1[User Service<br/>Lambda Repo]
        REPO2[Order Service<br/>Lambda Repo]
        REPO3[Product Service<br/>Lambda Repo]
    end

    subgraph "GitHub Actions"
        GH1[Deploy Infrastructure]
        GH2[Deploy Lambda 1]
        GH3[Deploy Lambda 2]
        GH4[Deploy Lambda 3]
    end

    Internet --> NAT
    NAT --> PRIV1
    NAT --> PRIV2

    PRIV1 -.-> API
    PRIV2 -.-> API

    GH1 --> VPC
    GH1 --> API
    GH1 --> S3
    GH1 --> IAM

    GH2 --> REPO1
    GH3 --> REPO2
    GH4 --> REPO3

    REPO1 -.-> PRIV1
    REPO2 -.-> PRIV1
    REPO3 -.-> PRIV2

    REPO1 -.-> API
    REPO2 -.-> API
    REPO3 -.-> API
```

## Network Architecture

### VPC Design

- **CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **Multi-AZ**: Deployed across 2 availability zones for redundancy
- **DNS**: Enabled for internal service discovery

### Subnet Strategy

| Subnet Type | CIDR          | Purpose                              | Internet Access |
| ----------- | ------------- | ------------------------------------ | --------------- |
| Public 1    | 10.0.101.0/24 | NAT Gateway, future public resources | Direct via IGW  |
| Public 2    | 10.0.102.0/24 | Reserved for scaling                 | Direct via IGW  |
| Private 1   | 10.0.1.0/24   | Lambda functions                     | Via NAT Gateway |
| Private 2   | 10.0.2.0/24   | Lambda functions                     | Via NAT Gateway |

### Routing

- **Public Route Table**: Routes to Internet Gateway for public access
- **Private Route Table**: Routes to NAT Gateway for outbound internet access
- **VPC Endpoints**: Direct access to S3 and DynamoDB (cost optimization)

## Security Architecture

### Network Security

```mermaid
graph LR
    subgraph "Security Layers"
        subgraph "Network Level"
            NACL[Network ACLs<br/>Subnet-level]
            SG[Security Groups<br/>Instance-level]
        end

        subgraph "Application Level"
            IAM[IAM Roles<br/>Service permissions]
            API_AUTH[API Gateway<br/>Authentication]
        end

        subgraph "Data Level"
            S3_ENC[S3 Encryption<br/>At-rest]
            CW_ENC[CloudWatch<br/>Log encryption]
        end
    end

    Internet --> NACL
    NACL --> SG
    SG --> IAM
    IAM --> API_AUTH
    API_AUTH --> S3_ENC
    S3_ENC --> CW_ENC
```

### Security Groups

- **Lambda Security Group**: Outbound only (443, 80) for AWS API calls
- **Default Deny**: No inbound traffic allowed to Lambda functions
- **Least Privilege**: Minimal required permissions

### IAM Strategy

- **Lambda Execution Role**: VPC access + CloudWatch logs
- **GitHub Actions Role**: Deployment permissions only
- **Cross-Service Permissions**: API Gateway → Lambda invoke only

## API Gateway Architecture

### REST API Design

```mermaid
graph TD
    CLIENT[Client Applications] --> API[API Gateway<br/>REST API]

    subgraph "API Gateway"
        STAGE[Stage: api]
        AUTH[Authorization<br/>Optional]
        THROTTLE[Throttling<br/>Rate Limiting]
        CACHE[Response Caching<br/>Optional]
    end

    API --> STAGE
    STAGE --> AUTH
    AUTH --> THROTTLE
    THROTTLE --> CACHE

    subgraph "Lambda Functions"
        LAMBDA1[User Service<br/>Lambda]
        LAMBDA2[Order Service<br/>Lambda]
        LAMBDA3[Product Service<br/>Lambda]
    end

    CACHE --> LAMBDA1
    CACHE --> LAMBDA2
    CACHE --> LAMBDA3
```

### Resource Structure

- **Base URL**: `https://{api-id}.execute-api.us-east-1.amazonaws.com/api`
- **Resource Pattern**: `/{service}/{action}`
- **Integration**: Lambda Proxy Integration for all functions

## Data Flow Architecture

### Deployment Flow

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant GH as GitHub Actions
    participant S3 as S3 Bucket
    participant TF as Terraform
    participant AWS as AWS Services

    DEV->>GH: Push Lambda Code
    GH->>GH: Build & Package
    GH->>S3: Upload Package
    GH->>TF: Reference Shared Infra
    TF->>AWS: Deploy Lambda
    AWS->>AWS: Connect to VPC/API Gateway
```

### Request Flow

```mermaid
sequenceDiagram
    participant CLIENT as Client
    participant API as API Gateway
    participant LAMBDA as Lambda Function
    participant VPC as VPC Resources
    participant EXT as External APIs

    CLIENT->>API: HTTP Request
    API->>API: Authentication/Throttling
    API->>LAMBDA: Invoke Function
    LAMBDA->>VPC: Use VPC Resources
    LAMBDA->>EXT: External API Calls (via NAT)
    EXT->>LAMBDA: Response
    LAMBDA->>API: Function Response
    API->>CLIENT: HTTP Response
```

## Cost Architecture

### Shared Resources (Cost Savings)

| Resource    | Shared Benefit       | Monthly Cost\*         |
| ----------- | -------------------- | ---------------------- |
| VPC         | All Lambda functions | $0                     |
| NAT Gateway | All outbound traffic | ~$45                   |
| API Gateway | All HTTP endpoints   | $3.50/million requests |
| S3 Bucket   | All deployments      | $0.023/GB              |

\*Estimated costs - actual costs vary by usage

### Per-Lambda Costs

- **Lambda Function**: $0.0000166667/GB-second + $0.20/million requests
- **CloudWatch Logs**: $0.50/GB ingested
- **API Gateway Integration**: Included in shared cost

## Scaling Considerations

### Current Limits

- **Lambda Concurrent Executions**: 1,000 (can be increased)
- **API Gateway Requests**: 10,000/second (can be increased)
- **VPC IP Addresses**: ~65,000 available
- **NAT Gateway Bandwidth**: 45 Gbps

### Scaling Strategy

1. **Horizontal**: Add more Lambda functions using same infrastructure
2. **Vertical**: Increase Lambda memory/timeout per function
3. **Geographic**: Deploy in additional regions as needed
4. **Performance**: Add API Gateway caching and Lambda provisioned concurrency

## Monitoring Architecture

### Observability Stack

```mermaid
graph TD
    subgraph "Data Collection"
        API_LOGS[API Gateway<br/>Access Logs]
        LAMBDA_LOGS[Lambda<br/>Function Logs]
        VPC_LOGS[VPC<br/>Flow Logs]
    end

    subgraph "Processing"
        CW[CloudWatch<br/>Logs & Metrics]
        CW_DASH[CloudWatch<br/>Dashboard]
    end

    subgraph "Alerting"
        SNS[SNS Topics]
        ALERTS[CloudWatch<br/>Alarms]
    end

    API_LOGS --> CW
    LAMBDA_LOGS --> CW
    VPC_LOGS --> CW

    CW --> CW_DASH
    CW --> ALERTS
    ALERTS --> SNS
```

### Key Metrics

- **API Gateway**: Request count, latency, error rate
- **Lambda**: Duration, memory usage, error rate, throttles
- **VPC**: Network bytes in/out, NAT Gateway usage
- **Cost**: Monthly spend by service

This architecture provides a robust, scalable, and cost-effective foundation for Lambda-based applications while maintaining security and operational best practices.
