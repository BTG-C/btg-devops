# BTG Product AWS Deployment Guide

**Purpose:** Deploy BTG product infrastructure across multi-account AWS Organization

**Prerequisites:** Complete [AWS-ORGANIZATION-SETUP.md](./AWS-ORGANIZATION-SETUP.md) first

**Scope:** Terraform state management, ECS clusters, DocumentDB, ALB, CloudFront, S3, IAM roles for BTG

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites Verification](#3-prerequisites-verification)
4. [Terraform Backend Setup](#4-terraform-backend-setup)
5. [DocumentDB Cluster Setup](#5-documentdb-cluster-setup)
6. [ECS Platform Deployment](#6-ecs-platform-deployment)
7. [Backend Services Deployment](#7-backend-services-deployment)
8. [MFE Infrastructure Setup](#8-mfe-infrastructure-setup)
9. [GitHub Actions IAM Roles](#9-github-actions-iam-roles)
10. [DNS and SSL Certificates](#10-dns-and-ssl-certificates)
11. [Verification](#11-verification)
12. [Post-Deployment](#12-post-deployment)

---

## 1. Overview

### BTG Product Components

```
BTG Product (Betting Operations Platform)
├── Backend Services (Java Spring Boot)
│   ├── btg-auth-server (ECS: 8080, local: 9000)
│   ├── btg-gateway-service (ECS: 8080, local: 8080)
│   ├── btg-score-odd-service (ECS: 8080, local: 8082)
│   └── btg-enhancer-service (ECS: 8080, local: 8083)
├── Frontend Services (Angular MFE)
│   ├── btg-shell-mfe (host app)
│   ├── btg-enhancer-mfe (remote)
│   └── btg-shared-ui-lib (shared components)
└── Infrastructure
    ├── DocumentDB (MongoDB-compatible)
    ├── ECS Fargate (containerized services)
    ├── Application Load Balancer
    ├── CloudFront + S3 (MFE hosting)
    └── VPC with public/private subnets
```

### Deployment Flow

```
1. Terraform Backend (S3 + DynamoDB)
   ↓
2. DocumentDB Cluster (shared across services)
   ↓
3. ECS Cluster + ALB
   ↓
4. Backend Services (auth → gateway → score/enhancer)
   ↓
5. MFE Infrastructure (S3 + CloudFront)
   ↓
6. GitHub Actions IAM Roles
   ↓
7. DNS + SSL Certificates
```

---

## 2. Architecture

### Multi-Account Structure

```
punt-root (Management Account)
└── Engineering OU
    ├── punt-btg-dev (Account: 111111111111)
    │   └── All BTG dev resources
    ├── punt-btg-staging (Account: 222222222222)
    │   └── All BTG staging resources
    └── punt-btg-prod (Account: 333333333333)
        └── All BTG production resources
```

### Resource Naming Convention

| Resource Type | Pattern | Example |
|---------------|---------|---------|
| **S3 Buckets** | `punt-btg-{env}-{purpose}` | `punt-btg-dev-mfe-assets` |
| **State Buckets** | `punt-terraform-state-{env}` | `punt-terraform-state-dev` |
| **Lock Tables** | `punt-terraform-locks-{env}` | `punt-terraform-locks-dev` |
| **ECS Cluster** | `punt-btg-{env}-cluster` | `punt-btg-dev-cluster` |
| **ECS Service** | `punt-btg-{env}-{service}` | `punt-btg-dev-gateway` |
| **Target Groups** | `punt-btg-{env}-{service}-tg` | `punt-btg-dev-gateway-tg` |
| **CloudWatch Logs** | `/ecs/punt-btg-{env}-{service}` | `/ecs/punt-btg-dev-gateway` |
| **IAM Roles** | `punt-btg-{env}-{purpose}` | `punt-btg-dev-github-actions-mfe` |
| **DocumentDB** | `punt-btg-{env}-docdb` | `punt-btg-dev-docdb` |

### AWS Regions

- **Primary:** `us-east-1` (N. Virginia)
- **Failover:** `us-west-2` (Oregon) - future consideration

---

## 3. Prerequisites Verification

### Required CLI Profiles

Verify profiles configured in [AWS-ORGANIZATION-SETUP.md](./AWS-ORGANIZATION-SETUP.md):

```powershell
# Test all profiles
aws sts get-caller-identity --profile punt-btg-dev
aws sts get-caller-identity --profile punt-btg-staging
aws sts get-caller-identity --profile punt-btg-prod

# Should output:
# - Account: <respective-account-id>
# - UserId: <role-session-id>
# - Arn: arn:aws:sts::<account-id>:assumed-role/OrganizationAccountAccessRole/<session>
```

### Required Tools

```powershell
# Terraform
terraform version  # Required: v1.6+

# AWS CLI
aws --version      # Required: v2.0+

# Docker (for local testing)
docker --version   # Required: 20.10+
```

### Clone Repository

```powershell
# Clone btg-devops repo
cd c:\Git
git clone https://github.com/BTG-C/btg-devops.git
cd btg-devops
```

---

## 4. Terraform Backend Setup

### Why Separate Backend Setup?

Terraform state itself must be stored in S3, but we need S3 and DynamoDB **before** we can use remote state. This chicken-and-egg problem is solved by:

1. First: Create S3 + DynamoDB **without** remote backend (local state)
2. Then: Use those resources for all subsequent Terraform deployments

### Step 1: Create Backend Resources (Development)

```powershell
cd infrastructure/terraform/infra-setup-pre-terraform/dev

# Initialize Terraform (local backend)
terraform init

# Review plan
terraform plan

# Expected resources:
# - S3 bucket: punt-terraform-state-dev
# - DynamoDB table: punt-terraform-locks-dev
# - Bucket versioning enabled
# - Server-side encryption enabled

# Apply
terraform apply -auto-approve

# Verify
aws s3 ls --profile punt-btg-dev | Select-String "punt-terraform-state-dev"
aws dynamodb list-tables --profile punt-btg-dev --query 'TableNames[?contains(@, `punt-terraform-locks-dev`)]'
```

### Step 2: Create Backend Resources (Staging)

```powershell
cd ../staging

terraform init
terraform plan
terraform apply -auto-approve

# Verify
aws s3 ls --profile punt-btg-staging | Select-String "punt-terraform-state-staging"
```

### Step 3: Create Backend Resources (Production)

```powershell
cd ../prod

terraform init
terraform plan
terraform apply -auto-approve

# Verify
aws s3 ls --profile punt-btg-prod | Select-String "punt-terraform-state-prod"
```

### Architecture Created

```
Each AWS Account (dev/staging/prod):
├── S3 Bucket: punt-terraform-state-{env}
│   ├── Versioning: Enabled
│   ├── Encryption: AES256
│   └── Lifecycle: Retain old versions (30 days)
└── DynamoDB Table: punt-terraform-locks-{env}
    ├── Primary Key: LockID
    └── Billing Mode: PAY_PER_REQUEST
```

---

## 5. DocumentDB Cluster Setup

### Architecture

BTG uses a **single DocumentDB cluster per environment** with multiple databases:

```
DocumentDB Cluster: punt-btg-{env}-docdb
├── Database: btg_auth (authentication data)
├── Database: btg (main application data)
└── Databases: {service}_db (additional services)
```

### Connection Strings

```
# Auth Service
mongodb://admin:${password}@punt-btg-dev-docdb.cluster-xxx.us-east-1.docdb.amazonaws.com:27017/btg_auth?tls=true&replicaSet=rs0

# Gateway/Other Services
mongodb://admin:${password}@punt-btg-dev-docdb.cluster-xxx.us-east-1.docdb.amazonaws.com:27017/btg?tls=true&replicaSet=rs0
```

### Step 1: Create DocumentDB (Development)

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Review DocumentDB module configuration
Get-Content main.tf | Select-String -Pattern "module `"documentdb`""

# Initialize Terraform with remote backend
terraform init -backend-config="profile=punt-btg-dev"

# Plan (DocumentDB module)
terraform plan -target=module.documentdb

# Apply DocumentDB only
terraform apply -target=module.documentdb -auto-approve

# Get DocumentDB endpoint
terraform output documentdb_endpoint
# Example: punt-btg-dev-docdb.cluster-xxx.us-east-1.docdb.amazonaws.com
```

### Step 2: Store DocumentDB Password in Secrets Manager

```powershell
# Create secret for DocumentDB master password
aws secretsmanager create-secret `
  --name punt-btg-dev-docdb-password `
  --secret-string "YourSecurePassword123!" `
  --profile punt-btg-dev

# For application use (btg_auth database)
aws secretsmanager create-secret `
  --name punt-btg-dev-auth-db-credentials `
  --secret-string '{\"username\":\"admin\",\"password\":\"YourSecurePassword123!\",\"database\":\"btg_auth\"}' `
  --profile punt-btg-dev

# For other services (btg database)
aws secretsmanager create-secret `
  --name punt-btg-dev-main-db-credentials `
  --secret-string '{\"username\":\"admin\",\"password\":\"YourSecurePassword123!\",\"database\":\"btg\"}' `
  --profile punt-btg-dev
```

### Step 3: Create Databases

```powershell
# Connect via EC2 bastion (DocumentDB requires VPC access)
# Or use MongoDB shell from your VPC

# Download RDS CA certificate
Invoke-WebRequest -Uri "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" -OutFile "rds-ca-cert.pem"

# Connect to DocumentDB
mongosh --tls `
  --host punt-btg-dev-docdb.cluster-xxx.us-east-1.docdb.amazonaws.com:27017 `
  --tlsCAFile rds-ca-cert.pem `
  --username admin `
  --password

# Create databases
use btg_auth
db.createCollection("users")

use btg
db.createCollection("config")

# Exit
exit
```

### Step 4: Repeat for Staging & Production

```powershell
# Staging
cd ../env-staging
terraform init -backend-config="profile=punt-btg-staging"
terraform apply -target=module.documentdb -auto-approve

# Production
cd ../env-prod
terraform init -backend-config="profile=punt-btg-prod"
terraform apply -target=module.documentdb -auto-approve
```

---

## 6. ECS Platform Deployment

### Architecture

```
ECS Platform
├── ECS Cluster: punt-btg-{env}-cluster
├── VPC: 10.0.0.0/16
│   ├── Public Subnets (2 AZs)
│   └── Private Subnets (2 AZs)
├── Application Load Balancer (internet-facing)
├── Security Groups
└── CloudWatch Log Groups
```

### Step 1: Deploy ECS Platform (Development)

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Plan ECS platform
terraform plan -target=module.ecs_platform

# Review:
# - VPC and subnets
# - ECS cluster
# - ALB with listeners (80, 443)
# - Security groups

# Apply
terraform apply -target=module.ecs_platform -auto-approve

# Get outputs
terraform output alb_dns_name
# Example: punt-btg-dev-alb-1234567890.us-east-1.elb.amazonaws.com

terraform output ecs_cluster_name
# Example: punt-btg-dev-cluster
```

### Step 2: Verify ECS Cluster

```powershell
# List clusters
aws ecs list-clusters --profile punt-btg-dev

# Describe cluster
aws ecs describe-clusters `
  --clusters punt-btg-dev-cluster `
  --profile punt-btg-dev
```

### Step 3: Repeat for Staging & Production

```powershell
# Staging
cd ../env-staging
terraform init -backend-config="profile=punt-btg-staging"
terraform apply -target=module.ecs_platform -auto-approve

# Production
cd ../env-prod
terraform init -backend-config="profile=punt-btg-prod"
terraform apply -target=module.ecs_platform -auto-approve
```

---

## 7. Backend Services Deployment

### Service Deployment Order

**Critical:** Deploy services in dependency order:

1. **btg-auth-server** (authentication - no dependencies)
2. **btg-gateway-service** (API gateway - depends on auth)
3. **btg-score-odd-service** (scoring - depends on gateway)
4. **btg-enhancer-service** (enhancer - depends on gateway)

### Step 1: Build & Push Docker Images

```powershell
# Navigate to each service repo and build
cd c:\Git\btg-auth-server

# Login to GitHub Container Registry
echo $env:GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build image
docker build -t ghcr.io/btg-c/btg-auth-server:dev .

# Push image
docker push ghcr.io/btg-c/btg-auth-server:dev

# Repeat for other services:
# - ghcr.io/btg-c/btg-gateway-service:dev
# - ghcr.io/btg-c/btg-score-odd-service:dev
# - ghcr.io/btg-c/btg-enhancer-service:dev
```

### Step 2: Deploy Auth Service

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Update terraform.tfvars with image URIs
@"
auth_service_image = "ghcr.io/btg-c/btg-auth-server:dev"
"@ | Out-File -FilePath terraform.tfvars -Append

# Plan auth service
terraform plan -target=module.auth_service

# Apply
terraform apply -target=module.auth_service -auto-approve

# Verify service running
aws ecs list-services `
  --cluster punt-btg-dev-cluster `
  --profile punt-btg-dev

aws ecs describe-services `
  --cluster punt-btg-dev-cluster `
  --services punt-btg-dev-auth `
  --profile punt-btg-dev
```

### Step 3: Deploy Gateway Service

```powershell
# Update terraform.tfvars
@"
gateway_service_image = "ghcr.io/btg-c/btg-gateway-service:dev"
"@ | Out-File -FilePath terraform.tfvars -Append

# Apply
terraform apply -target=module.gateway_service -auto-approve
```

### Step 4: Deploy Remaining Services

```powershell
# Score & Odd Service
terraform apply -target=module.score_odd_service -auto-approve

# Enhancer Service
terraform apply -target=module.enhancer_service -auto-approve
```

### Step 5: Test Backend Services

```powershell
# Get ALB DNS name
$ALB_DNS = terraform output -raw alb_dns_name

# Test auth service health
Invoke-WebRequest -Uri "http://$ALB_DNS/auth/actuator/health"

# Test gateway service
Invoke-WebRequest -Uri "http://$ALB_DNS/api/health"

# Test score-odd service
Invoke-WebRequest -Uri "http://$ALB_DNS/score-odd/actuator/health"

# Test enhancer service
Invoke-WebRequest -Uri "http://$ALB_DNS/enhancer/actuator/health"
```

---

## 8. MFE Infrastructure Setup

### Architecture

```
MFE Infrastructure
├── S3 Bucket: punt-btg-{env}-mfe-assets
│   ├── index.html (shell app)
│   ├── remoteEntry.js (module federation)
│   └── Static assets (JS, CSS, images)
├── CloudFront Distribution
│   ├── Origin: S3 bucket
│   ├── SSL: ACM certificate
│   └── Custom domain: {env}.btg.puntedge.com
└── CloudFront OAI (Origin Access Identity)
```

### Step 1: Deploy MFE Infrastructure (Development)

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Plan MFE modules
terraform plan -target=module.mfe_s3
terraform plan -target=module.mfe_cloudfront
terraform plan -target=module.mfe_iam

# Apply all MFE modules
terraform apply `
  -target=module.mfe_s3 `
  -target=module.mfe_cloudfront `
  -target=module.mfe_iam `
  -auto-approve

# Get outputs
terraform output mfe_bucket_name
# Example: punt-btg-dev-mfe-assets

terraform output mfe_cloudfront_url
# Example: d1234567890abc.cloudfront.net
```

### Step 2: Verify S3 Bucket

```powershell
# List buckets
aws s3 ls --profile punt-btg-dev | Select-String "punt-btg-dev-mfe-assets"

# Check bucket policy (should allow CloudFront OAI)
aws s3api get-bucket-policy `
  --bucket punt-btg-dev-mfe-assets `
  --profile punt-btg-dev
```

### Step 3: Repeat for Staging & Production

```powershell
# Staging
cd ../env-staging
terraform apply -target=module.mfe_s3 -target=module.mfe_cloudfront -target=module.mfe_iam -auto-approve

# Production
cd ../env-prod
terraform apply -target=module.mfe_s3 -target=module.mfe_cloudfront -target=module.mfe_iam -auto-approve
```

---

## 9. GitHub Actions IAM Roles

### Purpose

GitHub Actions needs AWS credentials to:
- Push Docker images to ECR (if using ECR instead of GHCR)
- Deploy MFE assets to S3
- Invalidate CloudFront cache
- Deploy ECS services

### Step 1: Create OIDC Provider (One-time per account)

```powershell
# Development account
aws iam create-open-id-connect-provider `
  --url "https://token.actions.githubusercontent.com" `
  --client-id-list "sts.amazonaws.com" `
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" `
  --profile punt-btg-dev

# Staging
aws iam create-open-id-connect-provider `
  --url "https://token.actions.githubusercontent.com" `
  --client-id-list "sts.amazonaws.com" `
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" `
  --profile punt-btg-staging

# Production
aws iam create-open-id-connect-provider `
  --url "https://token.actions.githubusercontent.com" `
  --client-id-list "sts.amazonaws.com" `
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" `
  --profile punt-btg-prod
```

### Step 2: IAM Roles Already Created by Terraform

The `mfe_iam` module creates:
- `punt-btg-{env}-github-actions-mfe` (for MFE deployments)

Verify:

```powershell
# List roles
aws iam list-roles --profile punt-btg-dev `
  --query 'Roles[?contains(RoleName, `github-actions`)]'
```

### Step 3: Configure GitHub Secrets

Add these secrets to each repository (btg-shell-mfe, btg-enhancer-mfe):

```yaml
# Repository Settings → Secrets and Variables → Actions

AWS_REGION: us-east-1
AWS_ROLE_ARN_DEV: arn:aws:iam::111111111111:role/punt-btg-dev-github-actions-mfe
AWS_ROLE_ARN_STAGING: arn:aws:iam::222222222222:role/punt-btg-staging-github-actions-mfe
AWS_ROLE_ARN_PROD: arn:aws:iam::333333333333:role/punt-btg-prod-github-actions-mfe
S3_BUCKET_DEV: punt-btg-dev-mfe-assets
S3_BUCKET_STAGING: punt-btg-staging-mfe-assets
S3_BUCKET_PROD: punt-btg-prod-mfe-assets
CLOUDFRONT_DISTRIBUTION_ID_DEV: E1234567890ABC
CLOUDFRONT_DISTRIBUTION_ID_STAGING: E0987654321DEF
CLOUDFRONT_DISTRIBUTION_ID_PROD: EXYZABC123456
```

### Step 4: GitHub Actions Workflow Example

```yaml
# .github/workflows/deploy-mfe.yml
name: Deploy MFE

on:
  push:
    branches: [main]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_DEV }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Build MFE
        run: npm run build
      
      - name: Deploy to S3
        run: |
          aws s3 sync dist/ s3://${{ secrets.S3_BUCKET_DEV }}/ --delete
      
      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID_DEV }} \
            --paths "/*"
```

---

## 10. DNS and SSL Certificates

### Step 1: Purchase Domain (If Not Already Owned)

```powershell
# Check domain availability
aws route53domains check-domain-availability `
  --domain-name puntedge.com `
  --profile punt-root

# Register domain (one-time, from root account)
aws route53domains register-domain `
  --domain-name puntedge.com `
  --duration-in-years 5 `
  --admin-contact file://contact.json `
  --registrant-contact file://contact.json `
  --tech-contact file://contact.json `
  --profile punt-root
```

### Step 2: Create Hosted Zone (Root Account)

```powershell
# Create hosted zone (if not exists)
aws route53 create-hosted-zone `
  --name puntedge.com `
  --caller-reference $(Get-Date -Format "yyyyMMddHHmmss") `
  --profile punt-root

# Get name servers
aws route53 list-hosted-zones --profile punt-root
```

### Step 3: Request SSL Certificate (per environment)

```powershell
# Development
aws acm request-certificate `
  --domain-name dev.btg.puntedge.com `
  --validation-method DNS `
  --profile punt-btg-dev

# Get certificate ARN and validation records
aws acm describe-certificate `
  --certificate-arn <cert-arn> `
  --profile punt-btg-dev

# Add CNAME records to Route 53 for validation
# (ACM console provides exact records needed)

# Wait for validation (5-30 minutes)
aws acm wait certificate-validated `
  --certificate-arn <cert-arn> `
  --profile punt-btg-dev
```

### Step 4: Create DNS Records

```powershell
# Create A record for dev environment (points to CloudFront)
# Get CloudFront distribution domain
$CF_DOMAIN = terraform output -raw mfe_cloudfront_url

# Create Route 53 record (via root account)
aws route53 change-resource-record-sets `
  --hosted-zone-id <zone-id> `
  --change-batch file://dns-change.json `
  --profile punt-root

# dns-change.json:
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "dev.btg.puntedge.com",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "${CF_DOMAIN}"}]
    }
  }]
}
```

### Step 5: Update CloudFront with Custom Domain

```powershell
# Update Terraform with certificate ARN and custom domain
# Edit env-dev/terraform.tfvars:

@"
mfe_domain_name = "dev.btg.puntedge.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/xxx"
"@ | Out-File -FilePath terraform.tfvars -Append

# Apply CloudFront update
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform apply -target=module.mfe_cloudfront -auto-approve
```

---

## 11. Verification

### Complete Infrastructure Checklist

```powershell
# ✅ Terraform Backend
aws s3 ls --profile punt-btg-dev | Select-String "punt-terraform-state"
aws dynamodb list-tables --profile punt-btg-dev | Select-String "punt-terraform-locks"

# ✅ DocumentDB
terraform output -raw documentdb_endpoint

# ✅ ECS Cluster
aws ecs list-clusters --profile punt-btg-dev

# ✅ ECS Services (should show 4 services)
aws ecs list-services --cluster punt-btg-dev-cluster --profile punt-btg-dev

# ✅ ALB Health Checks
$ALB_DNS = terraform output -raw alb_dns_name
Invoke-WebRequest -Uri "http://$ALB_DNS/auth/actuator/health"
Invoke-WebRequest -Uri "http://$ALB_DNS/api/health"

# ✅ S3 MFE Bucket
aws s3 ls s3://punt-btg-dev-mfe-assets/ --profile punt-btg-dev

# ✅ CloudFront Distribution
aws cloudfront list-distributions --profile punt-btg-dev

# ✅ IAM Roles
aws iam get-role --role-name punt-btg-dev-github-actions-mfe --profile punt-btg-dev

# ✅ DNS Resolution
nslookup dev.btg.puntedge.com

# ✅ SSL Certificate
Invoke-WebRequest -Uri "https://dev.btg.puntedge.com"
```

### Service Endpoints

| Service | URL | Container Port |
|---------|-----|----------------|
| **Auth** | `http://{alb-dns}/auth/actuator/health` | 8080 (ECS) |
| **Gateway** | `http://{alb-dns}/api/health` | 8080 (ECS) |
| **Score-Odd** | `http://{alb-dns}/score-odd/actuator/health` | 8080 (ECS) |
| **Enhancer** | `http://{alb-dns}/enhancer/actuator/health` | 8080 (ECS) |
| **MFE (Shell)** | `https://dev.btg.puntedge.com` | N/A (S3/CloudFront) |

**Note:** All backend services use port 8080 in ECS containers. Different ports (9000, 8080, 8082, 8083) are used only for local development to avoid conflicts.

---

## 12. Post-Deployment

### Enable Monitoring

```powershell
# CloudWatch alarms already created by Terraform
# Verify alarms exist:
aws cloudwatch describe-alarms --profile punt-btg-dev

# Key metrics:
# - ECS CPU/Memory utilization
# - ALB target health
# - DocumentDB connections
# - CloudFront error rates
```

### Configure Auto-Scaling (Optional)

```powershell
# ECS service auto-scaling based on CPU
aws application-autoscaling register-scalable-target `
  --service-namespace ecs `
  --scalable-dimension ecs:service:DesiredCount `
  --resource-id service/punt-btg-dev-cluster/punt-btg-dev-gateway `
  --min-capacity 2 `
  --max-capacity 10 `
  --profile punt-btg-dev

aws application-autoscaling put-scaling-policy `
  --service-namespace ecs `
  --scalable-dimension ecs:service:DesiredCount `
  --resource-id service/punt-btg-dev-cluster/punt-btg-dev-gateway `
  --policy-name cpu-scaling `
  --policy-type TargetTrackingScaling `
  --target-tracking-scaling-policy-configuration file://scaling-policy.json `
  --profile punt-btg-dev
```

### Backup Strategy

```powershell
# DocumentDB automated backups (already enabled)
# Retention period: 7 days (configurable in Terraform)

# Verify backup settings
aws docdb describe-db-clusters `
  --db-cluster-identifier punt-btg-dev-docdb `
  --profile punt-btg-dev `
  --query 'DBClusters[0].[BackupRetentionPeriod,PreferredBackupWindow]'
```

### Cost Optimization

```powershell
# Enable Cost Explorer tags
# AWS Console → Billing → Cost Allocation Tags
# Activate: Environment, Product, CostCenter, ManagedBy

# Set up budget alerts
aws budgets create-budget `
  --account-id 111111111111 `
  --budget file://budget.json `
  --profile punt-btg-dev

# budget.json example (monthly $500 budget):
{
  "BudgetName": "punt-btg-dev-monthly",
  "BudgetLimit": {
    "Amount": "500",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### Security Hardening

- ✅ Enable AWS Config for compliance monitoring
- ✅ Enable GuardDuty for threat detection
- ✅ Enable Security Hub for security posture
- ✅ Rotate DocumentDB passwords every 90 days
- ✅ Review IAM policies quarterly
- ✅ Enable MFA delete on S3 state buckets

---

## Appendix: Resource Reference

### Development Environment (punt-btg-dev)

| Resource | Name/ID | Purpose |
|----------|---------|---------|
| **Account ID** | `111111111111` | AWS account identifier |
| **S3 State** | `punt-terraform-state-dev` | Terraform state storage |
| **DynamoDB Lock** | `punt-terraform-locks-dev` | Terraform state locking |
| **DocumentDB** | `punt-btg-dev-docdb` | MongoDB-compatible database |
| **ECS Cluster** | `punt-btg-dev-cluster` | Container orchestration |
| **ALB** | `punt-btg-dev-alb` | Load balancer |
| **S3 MFE** | `punt-btg-dev-mfe-assets` | Frontend hosting |
| **CloudFront** | `E1234567890ABC` | CDN distribution |
| **IAM Role** | `punt-btg-dev-github-actions-mfe` | GitHub CI/CD |

### Staging Environment (punt-btg-staging)

| Resource | Name/ID | Purpose |
|----------|---------|---------|
| **Account ID** | `222222222222` | AWS account identifier |
| *(Same resource types as dev)* | `punt-btg-staging-*` | Staging resources |

### Production Environment (punt-btg-prod)

| Resource | Name/ID | Purpose |
|----------|---------|---------|
| **Account ID** | `333333333333` | AWS account identifier |
| *(Same resource types as dev)* | `punt-btg-prod-*` | Production resources |

---

## Troubleshooting

### Issue: Terraform state lock timeout

**Solution:**
```powershell
# Release stuck lock
aws dynamodb delete-item `
  --table-name punt-terraform-locks-dev `
  --key '{"LockID":{"S":"punt-terraform-state-dev/env-dev"}}' `
  --profile punt-btg-dev
```

### Issue: ECS service fails to start

**Solution:**
```powershell
# Check CloudWatch logs
aws logs tail /ecs/punt-btg-dev-gateway --follow --profile punt-btg-dev

# Check task definition
aws ecs describe-task-definition `
  --task-definition punt-btg-dev-gateway `
  --profile punt-btg-dev

# Common causes:
# - Wrong image URI
# - Missing secrets
# - Insufficient task CPU/memory
```

### Issue: ALB health checks failing

**Solution:**
```powershell
# Check target group health
aws elbv2 describe-target-health `
  --target-group-arn <tg-arn> `
  --profile punt-btg-dev

# Verify security group allows ALB → ECS traffic (port 8080-8083)
```

### Issue: CloudFront shows 403 Forbidden

**Solution:**
```powershell
# Verify S3 bucket policy allows CloudFront OAI
aws s3api get-bucket-policy `
  --bucket punt-btg-dev-mfe-assets `
  --profile punt-btg-dev

# Verify index.html exists
aws s3 ls s3://punt-btg-dev-mfe-assets/ --profile punt-btg-dev
```

---

**Document Version:** 1.0  
**Last Updated:** January 21, 2026  
**Maintained By:** BTG DevOps Team
