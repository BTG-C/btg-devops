# AWS Infrastructure Setup Guide

## Overview

This guide shows how to deploy the **BTG MFE infrastructure** to AWS using **Terraform**. The infrastructure supports unlimited MFEs (tested up to 30+) with a single S3 bucket + CloudFront architecture.

**Prerequisites**: Complete [AWS_PREREQUISITES.md](./AWS_PREREQUISITES.md) first!

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     GitHub Actions (OIDC)                     │
│  ┌────────────────┐              ┌────────────────┐          │
│  │ btg-shell-mfe  │              │btg-enhancer-mfe│          │
│  │ develop→dev    │              │ develop→dev    │          │
│  │ release→staging│              │ release→staging│          │
│  └────────┬───────┘              └────────┬───────┘          │
└───────────┼──────────────────────────────┼──────────────────┘
            │                              │
            │         Assume IAM Role      │
            ▼                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure                         │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              S3 Bucket (Single Bucket)               │   │
│  │  s3://btg-{env}-blue/                               │   │
│  │  ├── index.html (Shell)                             │   │
│  │  ├── config/config.json                             │   │
│  │  ├── mfe-bundles/                                   │   │
│  │  │   ├── enhancer/remoteEntry.json                  │   │
│  │  │   └── analytics/ (future MFEs)                   │   │
│  │  └── assets/                                        │   │
│  │      ├── shell/                                     │   │
│  │      └── enhancer/                                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ▲                                    │
│                          │                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         CloudFront Distribution (Global CDN)         │   │
│  │  https://d123abc.cloudfront.net                      │   │
│  │  • No-cache: config/*, remoteEntry.json              │   │
│  │  • 1-year cache: assets/*, *.js, *.css               │   │
│  │  • Security headers, OAC, TLS 1.2+                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    IAM Role (GitHub OIDC Trust)                      │   │
│  │    Trusts: BTG-C/btg-*-mfe                          │   │
│  │    Permissions: S3, CloudFront, SSM                  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 1. Complete Prerequisites

✅ Ensure you've completed [AWS_PREREQUISITES.md](./AWS_PREREQUISITES.md):
- AWS account created
- IAM user with credentials
- AWS CLI configured
- Terraform installed
- GitHub OIDC provider created

### 2. Initialize Terraform

```powershell
# IMPORTANT: Multi-account setup - complete backend setup first!
# See: infrastructure/terraform/infra-setup-pre-terraform/README.md

# Navigate to desired environment
cd c:\Git\btg-devops\infrastructure\terraform\env-dev   # For dev account
# OR
cd c:\Git\btg-devops\infrastructure\terraform\env-staging   # For prod account
# OR
cd c:\Git\btg-devops\infrastructure\terraform\env-prod   # For prod account

# Initialize Terraform (downloads providers & connects to remote state)
terraform init

# Validate configuration
terraform validate
```

**Expected output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

---

## Deploy Infrastructure

### Development Environment (Dev AWS Account)

```powershell
# Authenticate to dev AWS account
aws configure --profile btg-dev

# Navigate to dev environment
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Preview what will be created
terraform plan

# Create infrastructure
terraform apply -var-file="environments/dev.tfvars"
```

**Review the plan carefully**, then type `yes` to confirm.

**Resources created**:
- S3 bucket: `btg-dev-blue`
- CloudFront distribution
- IAM role: `btg-dev-github-actions-role`
- SSM parameters (if blue-green enabled)

**Time**: ~5-10 minutes

### Staging Environment

```powershell
terraform plan -var-file="environments/staging.tfvars"
terraform apply -var-file="environments/staging.tfvars"
```

**Resources created**:
- S3 buckets: `btg-staging-blue` + `btg-staging-green`
- CloudFront distributions (blue + green)
- IAM role: `btg-staging-github-actions-role`
- SSM parameter: `/btg/staging/active-env`

### Production Environment

```powershell
terraform plan -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

**Resources created**:
- S3 buckets: `btg-prod-blue` + `btg-prod-green`
- CloudFront distributions (blue + green)
- IAM role: `btg-prod-github-actions-role`
- SSM parameter: `/btg/prod/active-env`

---

## Capture Outputs

After each `terraform apply`, save these outputs for GitHub Secrets:

```powershell
# Display all outputs
terraform output

# Get specific values
terraform output -raw github_actions_role_arn
terraform output -raw s3_bucket_name
terraform output -raw cloudfront_distribution_id
terraform output -raw cloudfront_url
```

**Example output**:
```
github_actions_role_arn = "arn:aws:iam::123456789012:role/btg-dev-github-actions-role"
s3_bucket_name = "btg-dev-blue"
cloudfront_distribution_id = "E1234567890ABC"
cloudfront_url = "https://d1a2b3c4d5e6f7.cloudfront.net"
```

### Add to GitHub Secrets

For **each repository** (btg-shell-mfe, btg-enhancer-mfe):

**Settings → Secrets and variables → Actions → Repository secrets**:

```
AWS_ROLE_ARN_DEV      = arn:aws:iam::123456789012:role/btg-dev-github-actions-role
S3_BUCKET_DEV         = btg-dev-blue
CLOUDFRONT_ID_DEV     = E1234567890ABC

AWS_ROLE_ARN_STAGING  = arn:aws:iam::123456789012:role/btg-staging-github-actions-role
S3_BUCKET_STAGING     = btg-staging-blue
CLOUDFRONT_ID_STAGING = E0987654321XYZ

AWS_ROLE_ARN_PROD     = arn:aws:iam::123456789012:role/btg-prod-github-actions-role
S3_BUCKET_PROD        = btg-prod-blue
CLOUDFRONT_ID_PROD    = EABCDEF123456
```

---

## Verify Infrastructure

### 1. Check S3 Bucket

```powershell
# List S3 buckets
aws s3 ls | Select-String "btg"

# Check bucket contents (should be empty initially)
aws s3 ls s3://btg-dev-blue/
```

### 2. Check CloudFront Distribution

```powershell
# Get distribution details
aws cloudfront get-distribution --id E1234567890ABC

# Check distribution status
aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='CDN for btg dev MFE'].{Id:Id,Status:Status,DomainName:DomainName}"
```

### 3. Test CloudFront URL

```powershell
# Open CloudFront URL in browser
$cloudfrontUrl = terraform output -raw cloudfront_url
Start-Process $cloudfrontUrl
```

**Expected**: 403 error (no content yet - this is correct!)

### 4. Verify IAM Role

```powershell
# Get role details
aws iam get-role --role-name btg-dev-github-actions-role

# Check trust policy allows GitHub OIDC
aws iam get-role --role-name btg-dev-github-actions-role --query 'Role.AssumeRolePolicyDocument'
```

---

## Test Deployment

### Manual Test Deploy

Create a simple test file and deploy it:

```powershell
# Create test HTML
@"
<!DOCTYPE html>
<html>
<head><title>BTG MFE Test</title></head>
<body>
  <h1>BTG Infrastructure Test</h1>
  <p>If you see this, infrastructure is working!</p>
</body>
</html>
"@ | Out-File -FilePath test.html -Encoding utf8

# Upload to S3
aws s3 cp test.html s3://btg-dev-blue/test.html `
  --cache-control "no-cache"

# Create CloudFront invalidation
aws cloudfront create-invalidation `
  --distribution-id E1234567890ABC `
  --paths "/test.html"

# Wait 30 seconds for invalidation
Start-Sleep -Seconds 30

# Test URL
$testUrl = "$(terraform output -raw cloudfront_url)/test.html"
Write-Host "Testing: $testUrl"
Start-Process $testUrl
```

**Expected**: Your test HTML page displays correctly.

### Clean Up Test File

```powershell
aws s3 rm s3://btg-dev-blue/test.html
```

---

## Configuration Reference

### Environment-Specific Settings

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| **S3 Buckets** | 1 (blue) | 2 (blue + green) | 2 (blue + green) |
| **CloudFront Price Class** | PriceClass_100 | PriceClass_100 | PriceClass_All |
| **Version Retention** | 7 days | 7 days | 30 days |
| **Blue-Green** | ❌ Disabled | ✅ Enabled | ✅ Enabled |

### CloudFront Cache Policies

| Path | Cache Policy | TTL | Reason |
|------|-------------|-----|--------|
| `/config/*` | Disabled | 0 | Runtime config changes |
| `/remoteEntry.json` | Disabled | 0 | Shell module federation |
| `/mfe-bundles/*/remoteEntry.json` | Disabled | 0 | MFE module federation |
| `/assets/*` | Optimized | 1 year | Static assets (immutable) |
| `/*.js` | Optimized | 1 year | JS bundles (hashed) |
| `/*.css` | Optimized | 1 year | CSS files (hashed) |
| Default | Disabled | 0 | Shell HTML (index.html) |

---

## Infrastructure Management

### View Current State

```powershell
# List all resources
terraform state list

# Show specific resource
terraform state show aws_s3_bucket.mfe_bucket

# Get infrastructure summary
terraform show
```

### Update Infrastructure

```powershell
# Modify environments/*.tfvars or *.tf files

# Preview changes
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"
```

### Destroy Infrastructure (⚠️ CAUTION)

```powershell
# Preview what will be destroyed
terraform plan -destroy -var-file="environments/dev.tfvars"

# Destroy (requires manual confirmation)
terraform destroy -var-file="environments/dev.tfvars"
```

**⚠️ WARNING**: This deletes all resources including S3 buckets with data!

---

## Blue-Green Deployment

### Check Active Environment

```powershell
# Get active environment (staging/prod only)
aws ssm get-parameter --name "/btg/prod/active-env" --query 'Parameter.Value' --output text
```

**Output**: `blue` or `green`

### Switch Environments

```powershell
# Switch to green
aws ssm put-parameter `
  --name "/btg/prod/active-env" `
  --value "green" `
  --overwrite

# Verify switch
aws ssm get-parameter --name "/btg/prod/active-env" --query 'Parameter.Value' --output text
```

**Note**: This updates SSM parameter only. CloudFront distribution switching requires additional automation or manual update.

---

## Troubleshooting

### Terraform Errors

#### Error: "Resource already exists"

```powershell
# Import existing resource
terraform import aws_s3_bucket.mfe_bucket btg-dev-blue
```

#### Error: "GitHub OIDC provider not found"

```powershell
# Verify provider exists
aws iam list-open-id-connect-providers

# If missing, create it (see AWS_PREREQUISITES.md)
aws iam create-open-id-connect-provider `
  --url https://token.actions.githubusercontent.com `
  --client-id-list sts.amazonaws.com `
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### Error: "Insufficient permissions"

```powershell
# Check current user
aws sts get-caller-identity

# Verify user has AdministratorAccess or custom policy
aws iam list-attached-user-policies --user-name terraform-admin
```

### CloudFront Issues

#### 403 Forbidden Error

**Causes**:
1. S3 bucket is empty (expected before first deployment)
2. Origin Access Control misconfigured
3. S3 bucket policy missing

**Fix**:
```powershell
# Check bucket policy
aws s3api get-bucket-policy --bucket btg-dev-blue

# Re-apply Terraform
terraform apply -var-file="environments/dev.tfvars"
```

#### Content Not Updating

**Cause**: CloudFront cache not invalidated

**Fix**:
```powershell
# Create invalidation
aws cloudfront create-invalidation `
  --distribution-id E1234567890ABC `
  --paths "/*"

# Check invalidation status
aws cloudfront get-invalidation `
  --distribution-id E1234567890ABC `
  --id I1A2B3C4D5E6F7
```

### S3 Issues

#### Access Denied

**Check bucket policy**:
```powershell
aws s3api get-bucket-policy --bucket btg-dev-blue
```

**Check public access block**:
```powershell
aws s3api get-public-access-block --bucket btg-dev-blue
```

**Expected**: All blocks enabled (buckets are private, CloudFront has OAC access)

---

## Cost Monitoring

### Check Current Usage

```powershell
# S3 storage size
aws s3 ls s3://btg-dev-blue --recursive --summarize | Select-String "Total Size"

# CloudFront requests (last 24 hours)
aws cloudwatch get-metric-statistics `
  --namespace AWS/CloudFront `
  --metric-name Requests `
  --dimensions Name=DistributionId,Value=E1234567890ABC `
  --start-time (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
  --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
  --period 86400 `
  --statistics Sum
```

### Enable Cost Alerts

```powershell
# Create billing alarm (requires CloudWatch)
aws cloudwatch put-metric-alarm `
  --alarm-name btg-monthly-cost-alarm `
  --alarm-description "Alert when monthly costs exceed $50" `
  --metric-name EstimatedCharges `
  --namespace AWS/Billing `
  --statistic Maximum `
  --period 21600 `
  --threshold 50 `
  --comparison-operator GreaterThanThreshold
```

---

## Next Steps

After infrastructure is deployed:

1. ✅ **Copy CI/CD workflow** to shell and enhancer repos  
   See: [TEMPLATE-mfe-ci-cd.yml](../../.github/workflows/TEMPLATE-mfe-ci-cd.yml)

2. ✅ **Configure GitHub Secrets** with Terraform outputs

3. ✅ **Push code** to develop branch to trigger deployment

4. ✅ **Verify deployment** in AWS Console and browser

---

## Maintenance

### Regular Tasks

**Weekly**:
- Monitor CloudWatch metrics
- Check S3 storage growth
- Review CloudFront cache hit rate

**Monthly**:
- Review AWS cost reports
- Rotate IAM access keys (if using keys)
- Update Terraform provider versions

**Quarterly**:
- Review security groups and policies
- Audit IAM permissions
- Test disaster recovery procedures

### Terraform State Backup

```powershell
# Export current state
terraform show -json > terraform-state-backup-$(Get-Date -Format 'yyyyMMdd').json

# List state snapshots (if using S3 backend)
aws s3 ls s3://btg-terraform-state/btg-mfe/ --recursive
```

---

## Security Checklist

✅ **S3 Buckets**:
- Private access (no public read)
- Versioning enabled
- Encryption at rest (AES256)
- Lifecycle rules configured

✅ **CloudFront**:
- HTTPS only (redirect HTTP)
- TLS 1.2+ minimum
- Origin Access Control (OAC)
- Security headers policy

✅ **IAM**:
- OIDC authentication (no static keys)
- Least privilege permissions
- Trust policy scoped to GitHub repos
- Regular access reviews

✅ **Monitoring**:
- CloudWatch alarms configured
- Cost alerts enabled
- S3 access logging
- CloudFront logging

---

## Additional Resources

- **Terraform Infrastructure**: [../terraform/global/README.md](../terraform/global/README.md)
- **AWS Prerequisites**: [AWS_PREREQUISITES.md](./AWS_PREREQUISITES.md)
- **CI/CD Workflows**: [../../.github/workflows/TEMPLATE-mfe-ci-cd.yml](../../.github/workflows/TEMPLATE-mfe-ci-cd.yml)
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **AWS CloudFront**: https://docs.aws.amazon.com/cloudfront/
- **GitHub OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

---

## Summary

✅ **Infrastructure as Code**: Terraform manages all AWS resources  
✅ **Scalable**: Supports 30+ MFEs with no config changes  
✅ **Secure**: OIDC, encryption, private buckets, OAC  
✅ **Cost-Optimized**: Single bucket, regional price classes for dev/staging  
✅ **Production-Ready**: Blue-green deployment, versioning, monitoring  

**Your BTG MFE infrastructure is now deployed and ready for CI/CD!** 🚀