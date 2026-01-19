# Terraform Backend Setup

This directory contains one-time setup scripts for creating S3 buckets and DynamoDB tables to store Terraform state remotely.

## Why Remote State?

- **Separate AWS Accounts**: Dev, Staging, and Prod use different AWS accounts, so state must be isolated
- **Team Collaboration**: Multiple team members can run Terraform safely
- **State Locking**: DynamoDB prevents concurrent modifications
- **Security**: State contains sensitive data (ARNs, IDs), encrypted in S3

## Setup Instructions

### 1. Setup Development Account Backend

```powershell
# Authenticate to DEV AWS account
aws configure --profile btg-dev
# Enter: Access Key ID, Secret, Region (us-east-1), Output format (json)

# Create state backend infrastructure
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\dev
terraform init
terraform plan
terraform apply
```

**Output:**
```
state_bucket = "btg-terraform-state-dev"
lock_table   = "btg-terraform-locks-dev"
```

### 2. Setup Staging Account Backend

```powershell
# Authenticate to STAGING AWS account
aws configure --profile btg-staging

# Create state backend infrastructure
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\staging
terraform init
terraform plan
terraform apply
```

**Output:**
```
state_bucket = "btg-terraform-state-staging"
lock_table   = "btg-terraform-locks-staging"
```

### 3. Setup Production Account Backend

```powershell
# Authenticate to PROD AWS account
aws configure --profile btg-prod

# Create state backend infrastructure
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\prod
terraform init
terraform plan
terraform apply
```

**Output:**
```
state_bucket = "btg-terraform-state-prod"
lock_table   = "btg-terraform-locks-prod"
```

## After Backend Setup

Now you can deploy environments:

```powershell
# Deploy to DEV (uses btg-terraform-state-dev bucket)
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform init
terraform plan
terraform apply

# Deploy to STAGING (uses btg-terraform-state-prod bucket)
cd c:\Git\btg-devops\infrastructure\terraform\env-staging
terraform init
terraform plan
terraform apply

# Deploy to PROD (uses btg-terraform-state-prod bucket)
cd c:\Git\btg-devops\infrastructure\terraform\env-prod
terraform init
terraform plan
terraform apply
```

## Account Isolation

| Environment | AWS Account | State Bucket | Lock Table |
|-------------|-------------|--------------|------------|
| **dev** | Dev Account | `btg-terraform-state-dev` | `btg-terraform-locks-dev` |
| **staging** | Prod Account | `btg-terraform-state-prod` | `btg-terraform-locks-prod` |
| **prod** | Prod Account | `btg-terraform-state-prod` | `btg-terraform-locks-prod` |

Note: Staging and Prod share the same AWS account but have separate state files in the same bucket.

## State Storage Costs

- **S3 Storage**: ~$0.023/GB/month (state files are tiny, usually <1MB)
- **DynamoDB**: Pay-per-request (~$0 for low usage)
- **Total estimated cost**: <$1/month per account

## Disaster Recovery

State files are:
- ✅ Encrypted at rest (AES256)
- ✅ Versioned (can restore previous versions)
- ✅ Backed up automatically by AWS
- ✅ Locked during apply (prevents conflicts)

To restore a previous state version:

```powershell
# List state versions
aws s3api list-object-versions --bucket btg-terraform-state-dev --prefix mfe-infrastructure/dev/terraform.tfstate

# Download specific version
aws s3api get-object --bucket btg-terraform-state-dev --key mfe-infrastructure/dev/terraform.tfstate --version-id <VERSION_ID> terraform.tfstate.backup
```

## SSL/TLS Certificate Setup (ACM)

**ACM (AWS Certificate Manager)** provides free SSL/TLS certificates for HTTPS on Public ALB and CloudFront.

### Certificate Requirements

| Environment | Domain Example | Required? |
|-------------|----------------|-----------|
| **dev** | `dev.yourdomain.com` | Optional (HTTP works) |
| **staging** | `staging.yourdomain.com` | Recommended |
| **prod** | `yourdomain.com` | **Required** |

### Create Certificates Per Account

**Development Account (Optional):**
```bash
aws acm request-certificate \
  --domain-name "dev.yourdomain.com" \
  --subject-alternative-names "*.dev.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-dev
```

**Staging Account:**
```bash
aws acm request-certificate \
  --domain-name "staging.yourdomain.com" \
  --subject-alternative-names "*.staging.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-staging
```

**Production Account:**
```bash
aws acm request-certificate \
  --domain-name "yourdomain.com" \
  --subject-alternative-names "*.yourdomain.com" "www.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-prod
```

### Validate Certificate

1. **Add DNS CNAME records** shown in ACM console to your domain
2. **Wait 5-10 minutes** for validation
3. **Certificate status** changes to "Issued"
4. **Copy ARN**: `arn:aws:acm:us-east-1:123456789:certificate/abc-123`

### Add to Terraform

Create `terraform.tfvars` in each environment:

```hcl
# env-prod/terraform.tfvars
certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/abc-123"
```

### What It Enables

**With Certificate:**
- ✅ Public ALB serves HTTPS on port 443
- ✅ HTTP (port 80) redirects to HTTPS
- ✅ CloudFront uses custom domain with SSL
- ✅ Browser shows padlock (secure)

**Without Certificate (dev only):**
- HTTP only on port 80
- CloudFront uses default domain

### Certificate Features

- 🆓 **Free** for AWS services (ALB, CloudFront, API Gateway)
- 🔄 **Auto-renewal** every 13 months (zero maintenance)
- 🌐 **Wildcard support** (`*.yourdomain.com` covers all subdomains)
- 🔒 **TLS 1.3** latest security standards
- 🚀 **Instant attachment** to ALB/CloudFront

### Important Notes

- **Region: us-east-1 ONLY** - Required for CloudFront, works for ALB
- **DNS validation recommended** - Faster than email validation
- **Certificates are account-specific** - Create in each AWS account
- **Zero cost** - ACM public certificates are always free
