# Development Environment Setup Guide

Complete step-by-step guide to deploy the BTG application stack to AWS Dev environment.

**Estimated Time:** 2-3 hours (first-time setup)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: AWS Account Setup](#phase-1-aws-account-setup)
3. [Phase 2: GitHub Repository Configuration](#phase-2-github-repository-configuration)
4. [Phase 3: Publish Shared Libraries](#phase-3-publish-shared-libraries)
5. [Phase 4: Deploy Infrastructure](#phase-4-deploy-infrastructure)
6. [Phase 5: Update GitHub Secrets](#phase-5-update-github-secrets)
7. [Phase 6: Deploy Applications](#phase-6-deploy-applications)
8. [Phase 7: Verification](#phase-7-verification)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- [ ] **AWS CLI** (v2.x or higher)
- [ ] **Terraform** (v1.0 or higher)
- [ ] **Git** (configured with GitHub access)
- [ ] **PowerShell** (Windows) or **Bash** (Linux/Mac)
- [ ] **GitHub Account** with access to BTG-C organization

### Required Access

- [ ] AWS Account (with billing enabled)
- [ ] GitHub Personal Access Token (PAT) with `repo` scope
- [ ] Administrative access to BTG-C repositories

---

## Phase 1: AWS Account Setup

### 1.1 Create AWS Account

If you don't have an AWS account:

1. Navigate to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Provide email, password, and account name
4. Add payment method (credit card required)
5. Complete phone verification
6. Choose "Basic Support - Free" plan
7. Wait for account activation (5-10 minutes)

### 1.2 Create IAM User for Terraform

```powershell
# Sign in to AWS Console as root user
# Navigate to IAM → Users → Add users
# Username: terraform-admin
# Select: "Attach policies directly"
# Attach: AdministratorAccess policy
# Create user
```

**Create Access Key:**
```
1. Click on terraform-admin user
2. Security credentials tab → Create access key
3. Use case: Command Line Interface (CLI)
4. Add description: "Terraform CLI access"
5. Download .csv file (SAVE SECURELY!)
```

**Save credentials:**
```
Access Key ID: AKIAIOSFODNN7EXAMPLE
Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

⚠️ **CRITICAL:** You cannot retrieve the Secret Access Key again!

### 1.3 Configure AWS CLI

```powershell
# Configure AWS CLI with dev profile
aws configure --profile btg-dev

# Enter the following when prompted:
# AWS Access Key ID: [Your Access Key ID]
# AWS Secret Access Key: [Your Secret Access Key]
# Default region name: us-east-1
# Default output format: json
```

**Verify configuration:**
```powershell
aws sts get-caller-identity --profile btg-dev
```

Expected output:
```json
{
    "UserId": "AIDAIOSFODNN7EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-admin"
}
```

### 1.4 Create Terraform State Backend

```powershell
# Navigate to backend setup directory
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\dev

# Set AWS profile
$env:AWS_PROFILE = "btg-dev"

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Create backend infrastructure
terraform apply
# Type 'yes' when prompted
```

**Created resources:**
- S3 bucket: `btg-terraform-state-dev`
- DynamoDB table: `btg-terraform-locks-dev`

### 1.5 Create DocumentDB Master Password

```powershell
# Navigate to setup directory
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform

# Run password creation script
.\create-db-secrets.ps1 -Environment dev

# Verify secret was created
aws secretsmanager get-secret-value --secret-id "docdb/btg-dev/master-password" --profile btg-dev
```

**Created resource:**
- AWS Secret: `docdb/btg-dev/master-password`

### 1.6 Create GitHub OIDC Provider

```powershell
# Create OIDC provider in AWS
aws iam create-open-id-connect-provider `
  --url https://token.actions.githubusercontent.com `
  --client-id-list sts.amazonaws.com `
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 `
  --profile btg-dev
```

**OR via AWS Console:**
1. Navigate to IAM → Identity providers
2. Click "Add provider"
3. Provider type: OpenID Connect
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Add provider

### 1.7 Create Additional AWS Secrets

```powershell
# Set AWS profile
$env:AWS_PROFILE = "btg-dev"

# Create gateway client secret
$gatewaySecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
aws secretsmanager create-secret `
  --name "btg/dev/gateway-client-secret" `
  --secret-string $gatewaySecret `
  --region us-east-1

# Create Score-Odd API key (use your actual API key)
aws secretsmanager create-secret `
  --name "btg/dev/score-odd-api-key" `
  --secret-string "your-score-odd-api-key-here" `
  --region us-east-1

# Verify secrets
aws secretsmanager list-secrets --region us-east-1 | Select-String "btg/dev"
```

**Created secrets:**
- `btg/dev/gateway-client-secret`
- `btg/dev/score-odd-api-key`

---

## Phase 2: GitHub Repository Configuration

### 2.1 Create Personal Access Token (PAT)

1. Navigate to GitHub → Settings → Developer settings
2. Personal access tokens → Tokens (classic)
3. Generate new token (classic)
4. Name: `BTG DevOps Deployment Token`
5. Select scopes: **`repo`** (full control of private repositories)
6. Generate token
7. **COPY TOKEN IMMEDIATELY** (you won't see it again)

Example: `ghp_1234567890abcdefghijklmnopqrstuvwxyz`

### 2.2 Add Secret to Application Repositories

Add `DEVOPS_REPO_TOKEN` to these repositories:

**Backend Services:**
- `BTG-C/btg-gateway-service`
- `BTG-C/btg-auth-server`
- `BTG-C/btg-score-odd-service`
- `BTG-C/btg-enhancer-service`

**MFE Applications:**
- `BTG-C/btg-shell-mfe`
- `BTG-C/btg-enhancer-mfe`

**For each repository:**
```
1. Navigate to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: DEVOPS_REPO_TOKEN
4. Value: [Your GitHub PAT from step 2.1]
5. Add secret
```

### 2.3 Create GitHub Environment in btg-devops

1. Navigate to `BTG-C/btg-devops` repository
2. Settings → Environments
3. Click "New environment"
4. Name: `dev`
5. Click "Configure environment"

**DO NOT add secrets yet** - we'll add them after Terraform outputs the values.

---

## Phase 3: Publish Shared Libraries

Libraries must be published before applications can be built.

### 3.1 Publish Java Libraries

```powershell
# Publish btg-entities
cd c:\Git\btg-entities
git checkout main
git pull
git push  # Triggers publish.yml workflow

# Publish btg-service-commons
cd c:\Git\btg-service-commons
git checkout main
git pull
git push  # Triggers publish.yml workflow
```

### 3.2 Publish NPM Packages

```powershell
# Publish sass-design-system
cd c:\Git\sass-design-system
git checkout master
git pull
git push  # Triggers publish-package.yml workflow

# Publish btg-shared-ui-lib
cd c:\Git\btg-shared-ui-lib
git checkout master
git pull
git push  # Triggers publish-libraries.yml workflow
```

### 3.3 Verify Library Publication

Check GitHub Packages in each repository:
```
Repository → Packages (right sidebar)
```

Expected packages:
- `btg-entities` (Maven)
- `btg-service-commons` (Maven)
- `sass-design-system` (npm)
- `@btg/compliance-tools` (npm)
- `@btg/security-lib` (npm)
- `@btg/shared-components` (npm)
- `@btg/shared-state` (npm)

---

## Phase 4: Deploy Infrastructure

### 4.1 Initialize Terraform

```powershell
# Navigate to dev environment
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Set AWS profile
$env:AWS_PROFILE = "btg-dev"

# Initialize Terraform
terraform init
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

### 4.2 Review Terraform Plan

```powershell
# Generate execution plan
terraform plan

# Review the plan carefully - should show ~50-60 resources to create
```

Expected resources:
- 1 VPC with subnets, NAT, IGW
- 1 DocumentDB cluster (1 instance)
- 1 ECS cluster
- 2 Application Load Balancers (public + internal)
- 4 ECS services (placeholder images)
- 1 S3 bucket for MFE assets
- 1 CloudFront distribution
- IAM roles and security groups
- 1 AWS Budget

### 4.3 Apply Terraform Configuration

```powershell
# Deploy infrastructure
terraform apply

# Review the plan output
# Type 'yes' to confirm
```

⏱️ **Deployment time:** ~10-15 minutes

**Monitor progress:**
- VPC and networking: ~2 minutes
- DocumentDB cluster: ~5-8 minutes (slowest)
- ECS platform: ~2 minutes
- CloudFront distribution: ~2-3 minutes

### 4.4 Save Terraform Outputs

```powershell
# Get all outputs
terraform output

# Save to file for reference
terraform output > terraform-outputs.txt
```

**Important outputs (needed for next phase):**
```
vpc_id = "vpc-xxxxx"
ecs_cluster_name = "btg-dev-cluster"
public_alb_dns = "btg-dev-pub-alb-xxxxx.us-east-1.elb.amazonaws.com"
internal_alb_dns = "btg-dev-int-alb-xxxxx.us-east-1.elb.amazonaws.com"
docdb_endpoint = "btg-dev-docdb.cluster-xxxxx.us-east-1.docdb.amazonaws.com"
s3_bucket_name = "btg-dev-mfe-assets"
cloudfront_distribution_id = "E1234567890ABC"
cloudfront_url = "https://d123456.cloudfront.net"
github_actions_role_arn = "arn:aws:iam::123456789:role/btg-dev-github-actions-role"
```

---

## Phase 5: Update GitHub Secrets

Now that infrastructure is deployed, add the outputs to GitHub.

### 5.1 Get AWS Account ID

```powershell
aws sts get-caller-identity --profile btg-dev --query "Account" --output text
```

Example output: `123456789012`

### 5.2 Add Secrets to btg-devops "dev" Environment

Navigate to: `BTG-C/btg-devops` → Settings → Environments → dev → Add secret

Add these secrets:

| Secret Name | Value | Source |
|-------------|-------|--------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789:role/btg-dev-github-actions-role` | Terraform output: `github_actions_role_arn` |
| `AWS_REGION` | `us-east-1` | Fixed value |
| `AWS_ACCOUNT_ID` | `123456789012` | From step 5.1 |
| `GATEWAY_ALB_URL` | `http://btg-dev-pub-alb-xxxxx.us-east-1.elb.amazonaws.com` | Terraform output: `public_alb_dns` (add `http://`) |
| `S3_BUCKET_NAME` | `btg-dev-mfe-assets` | Terraform output: `s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E1234567890ABC` | Terraform output: `cloudfront_distribution_id` |
| `CLOUDFRONT_URL` | `https://d123456.cloudfront.net` | Terraform output: `cloudfront_url` |

---

## Phase 6: Deploy Applications

### 6.1 Deploy Backend Services

**IMPORTANT:** Deploy in this order (dependencies)

#### Step 1: Auth Server

```powershell
cd c:\Git\btg-auth-server
git checkout develop
git pull
git push  # Triggers artifact-pipeline.yml
```

**Workflow steps:**
1. Builds Java application
2. Creates Docker image
3. Pushes to `ghcr.io/btg-c/btg-auth-server:develop-{commit}-{timestamp}`
4. Triggers `btg-devops` deployment workflow
5. Updates ECS task definition
6. Deploys to `btg-dev-auth-server` service

**Monitor:** Check GitHub Actions in `btg-auth-server` repository

#### Step 2: Gateway Service

```powershell
cd c:\Git\btg-gateway-service
git checkout develop
git pull
git push
```

**Depends on:** Auth server must be deployed first

#### Step 3: Score-Odd Service

```powershell
cd c:\Git\btg-score-odd-service
git checkout develop
git pull
git push
```

#### Step 4: Enhancer Service

```powershell
cd c:\Git\btg-enhancer-service
git checkout develop
git pull
git push
```

**Depends on:** Score-Odd service

### 6.2 Deploy MFE Applications

#### Step 1: Enhancer MFE (Remote Module)

```powershell
cd c:\Git\btg-enhancer-mfe
git checkout develop
git pull
git push  # Triggers artifact-pipeline.yml
```

**Workflow steps:**
1. Builds Angular production bundle
2. Creates Docker image with assets
3. Pushes to `ghcr.io/btg-c/btg-enhancer-mfe:develop-{commit}-{timestamp}`
4. Triggers `btg-devops` MFE promotion workflow
5. Extracts assets from Docker image
6. Uploads to S3: `s3://btg-dev-mfe-assets/mfe-bundles/enhancer/`
7. Invalidates CloudFront cache

#### Step 2: Shell MFE (Host Application)

```powershell
cd c:\Git\btg-shell-mfe
git checkout develop
git pull
git push
```

**Workflow steps:**
1. Builds Angular production bundle
2. Creates Docker image
3. Pushes to `ghcr.io/btg-c/btg-shell-mfe:develop-{commit}-{timestamp}`
4. Triggers MFE promotion
5. Uploads assets to S3 root
6. **Deploys `config/config.json`** with dev-specific URLs
7. Invalidates CloudFront cache

---

## Phase 7: Verification

### 7.1 Check ECS Services

```powershell
# List services in cluster
aws ecs list-services --cluster btg-dev-cluster --profile btg-dev

# Check service status
aws ecs describe-services `
  --cluster btg-dev-cluster `
  --services btg-dev-gateway-service `
  --profile btg-dev `
  --query "services[0].{Status:status, Running:runningCount, Desired:desiredCount}"
```

**Expected services:**
- `btg-dev-gateway-service` (1 running task)
- `btg-dev-auth-server` (1 running task)
- `btg-dev-score-odd-service` (1 running task)
- `btg-dev-enhancer-service` (1 running task)

### 7.2 Check Backend Health

```powershell
# Get ALB DNS from Terraform output
$publicAlb = terraform output -raw public_alb_dns
$internalAlb = terraform output -raw internal_alb_dns

# Test gateway service
curl "http://$publicAlb/gateway-service/actuator/health"

# Test auth server
curl "http://$internalAlb/auth-server/actuator/health"

# Test score-odd service
curl "http://$internalAlb/score-odd-service/actuator/health"

# Test enhancer service
curl "http://$internalAlb/enhancer-service/actuator/health"
```

**Expected response (all services):**
```json
{"status":"UP"}
```

### 7.3 Check MFE Deployment

```powershell
# Get CloudFront URL
$cfUrl = terraform output -raw cloudfront_url

# Test shell-mfe config
curl "$cfUrl/config/config.json"

# Expected response:
# {
#   "backendBaseUrl": "https://api-dev.btgcric.com",
#   "environment": "dev",
#   "mfes": {
#     "enhancer": "https://dev.btgcric.com/mfe-bundles/enhancer/remoteEntry.json"
#   }
# }

# Test shell-mfe app
curl "$cfUrl/index.html"

# Test enhancer remote entry
curl "$cfUrl/mfe-bundles/enhancer/remoteEntry.json"
```

### 7.4 Access Application

**Via CloudFront:**
```
https://d123456.cloudfront.net
```

**Via Custom Domain (if configured):**
```
https://dev.btgcric.com
```

**Test Flow:**
1. Open browser to CloudFront URL
2. Should see shell-mfe loading screen
3. Login page should appear (auth-server)
4. After login, dashboard loads
5. Navigate to "Enhancer" section
6. Remote MFE should load seamlessly

---

## Troubleshooting

### Issue: Terraform State Lock Error

**Error:**
```
Error: Error acquiring the state lock
```

**Solution:**
```powershell
# Check for stuck locks
aws dynamodb scan --table-name btg-terraform-locks-dev --profile btg-dev

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue: ECS Service Failing to Start

**Error:** Tasks keep stopping, service unstable

**Diagnosis:**
```powershell
# Get task ARN
$taskArn = aws ecs list-tasks `
  --cluster btg-dev-cluster `
  --service-name btg-dev-gateway-service `
  --profile btg-dev `
  --query "taskArns[0]" --output text

# Check task logs
aws ecs describe-tasks `
  --cluster btg-dev-cluster `
  --tasks $taskArn `
  --profile btg-dev
```

**Common causes:**
- Image not found in GHCR (forgot to push from app repo)
- Secrets not created in AWS Secrets Manager
- Insufficient task memory/CPU
- Health check failing

### Issue: DocumentDB Connection Failed

**Error:** Services can't connect to DocumentDB

**Check:**
```powershell
# Verify DocumentDB is running
aws docdb describe-db-clusters `
  --db-cluster-identifier btg-dev-docdb `
  --profile btg-dev

# Check security group rules
aws ec2 describe-security-groups `
  --filters "Name=group-name,Values=btg-dev-docdb-sg" `
  --profile btg-dev
```

**Solution:**
- Ensure ECS tasks security group is allowed in DocumentDB security group
- Verify master password secret exists: `docdb/btg-dev/master-password`

### Issue: CloudFront Returns 403 Forbidden

**Error:** Accessing CloudFront URL returns 403

**Check:**
```powershell
# List S3 bucket contents
aws s3 ls s3://btg-dev-mfe-assets/ --recursive --profile btg-dev
```

**Common causes:**
- MFE not deployed yet (S3 bucket empty)
- CloudFront cache not invalidated
- OAC (Origin Access Control) misconfigured

**Solution:**
```powershell
# Manually invalidate CloudFront cache
aws cloudfront create-invalidation `
  --distribution-id E1234567890ABC `
  --paths "/*" `
  --profile btg-dev
```

### Issue: GitHub Actions Workflow Fails

**Error:** `Error: Credentials could not be loaded`

**Cause:** AWS_ROLE_ARN secret not set or OIDC provider not created

**Solution:**
1. Verify OIDC provider exists in AWS IAM
2. Verify `AWS_ROLE_ARN` secret in GitHub environment
3. Check IAM role trust policy includes GitHub OIDC

### Issue: Health Check Returns 503

**Error:** `/actuator/health` returns 503 Service Unavailable

**Possible causes:**
- Service still starting up (wait 1-2 minutes)
- Database connection failed
- Required secrets missing
- Dependency service not running

**Check logs:**
```powershell
# Get CloudWatch log stream
aws logs tail /ecs/btg-dev-gateway-service --follow --profile btg-dev
```

---

## Next Steps

After successful dev deployment:

1. **Test Application Functionality**
   - Create test user accounts
   - Test authentication flows
   - Verify MFE communication
   - Test API endpoints

2. **Setup Monitoring**
   - Configure CloudWatch alarms
   - Setup SNS notifications
   - Monitor budget alerts

3. **Deploy to Staging**
   - Repeat setup process for staging account
   - Use `env-staging` Terraform configuration
   - Configure staging GitHub environment

4. **Document Custom Configurations**
   - Record any deviations from defaults
   - Document API keys and external integrations
   - Update team runbooks

---

## Summary Checklist

### AWS Setup
- [ ] AWS account created
- [ ] IAM terraform-admin user created
- [ ] AWS CLI configured
- [ ] Terraform state backend created
- [ ] DocumentDB password secret created
- [ ] GitHub OIDC provider created
- [ ] Additional secrets created (gateway, score-odd)

### GitHub Setup
- [ ] Personal Access Token generated
- [ ] DEVOPS_REPO_TOKEN added to 6 app repositories
- [ ] GitHub "dev" environment created
- [ ] 7 secrets added to dev environment

### Library Publishing
- [ ] btg-entities published
- [ ] btg-service-commons published
- [ ] sass-design-system published
- [ ] btg-shared-ui-lib published

### Infrastructure
- [ ] Terraform initialized
- [ ] Terraform plan reviewed
- [ ] Terraform applied successfully
- [ ] All outputs saved

### Application Deployment
- [ ] Auth server deployed
- [ ] Gateway service deployed
- [ ] Score-Odd service deployed
- [ ] Enhancer service deployed
- [ ] Enhancer MFE deployed
- [ ] Shell MFE deployed

### Verification
- [ ] All ECS services running
- [ ] Health checks passing
- [ ] MFE accessible via CloudFront
- [ ] Config.json loading correctly
- [ ] Application login working

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review workflow logs in GitHub Actions
3. Check CloudWatch logs in AWS Console
4. Review Terraform state: `terraform show`

**Documentation References:**
- AWS Prerequisites: `docs/infrastructure/AWS-PREREQUISITES.md`
- AWS Setup: `docs/infrastructure/AWS-SETUP.md`
- MFE Configuration: `services/MFE-CONFIG-OVERRIDE.md`
- Configuration Flow: `docs/development/CONFIGURATION-FLOW.md`
