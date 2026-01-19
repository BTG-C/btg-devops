# Pre-Terraform Setup - Secrets & Certificates

## Overview

This guide covers manual setup steps that must be completed **before running Terraform** in each AWS account:

1. **DocumentDB Passwords** - Stored in AWS Secrets Manager
2. **ACM SSL Certificates** - For HTTPS on ALB and CloudFront

---

## 1. DocumentDB Password Setup

For maximum security, DocumentDB passwords are **manually created** in AWS Secrets Manager and are **never stored in Terraform state**.

## Setup Instructions

### Prerequisites
- AWS CLI installed and configured
- AWS credentials for the target account

### Steps

#### 1. Create Secret for Development Environment

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform
.\create-db-secrets.ps1 -Environment dev
```

#### 2. Create Secret for Staging Environment

```powershell
.\create-db-secrets.ps1 -Environment staging
```

#### 3. Create Secret for Production Environment

```powershell
.\create-db-secrets.ps1 -Environment prod
```

### What This Does

The script:
1. Generates a secure 32-character random password
2. Creates a secret in AWS Secrets Manager: `docdb/btg-{env}/master-password`
3. Stores the password in JSON format: `{"password": "..."}`

### After Running

You can now run Terraform:
```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform init
terraform apply
```

Terraform will:
- **Read** the password from Secrets Manager (never stores it in state)
- Create the DocumentDB cluster with that password
- Create a separate secret with full connection details

## Security Benefits

✅ **Password never in Terraform state** - Only stored in AWS Secrets Manager  
✅ **No password in source control** - Script generates it on-the-fly  
✅ **AWS encryption at rest** - Secrets Manager handles encryption  
✅ **Audit trail** - All secret access is logged in CloudTrail  

## Troubleshooting

### Secret Already Exists
If the secret exists, the script will ask if you want to update it. Choose "no" to keep the existing password.

### Manual Creation
You can also create the secret manually:

```powershell
# Generate password (PowerShell)
Add-Type -AssemblyName System.Web
$password = [System.Web.Security.Membership]::GeneratePassword(32, 10)

# Create secret in AWS
aws secretsmanager create-secret `
    --name "docdb/btg-dev/master-password" `
    --secret-string "{\"password\":\"$password\"}" `
    --region us-east-1
```

---

## 2. ACM SSL Certificate Setup

**ACM (AWS Certificate Manager)** provides **free SSL/TLS certificates** for HTTPS on ALB and CloudFront.

### Why ACM?

✅ **Free** for AWS services (ALB, CloudFront, API Gateway)  
✅ **Auto-renewal** every 13 months (zero maintenance)  
✅ **Wildcard support** covers all subdomains  
✅ **TLS 1.3** latest security standards  

### Certificate Requirements

| Environment | Required? | Domain Example |
|-------------|-----------|----------------|
| **dev** | Optional | `dev.yourdomain.com` |
| **staging** | Recommended | `staging.yourdomain.com` |
| **prod** | **Required** | `yourdomain.com` |

### Create Certificates

**Development (Optional):**
```bash
aws acm request-certificate \
  --domain-name "dev.yourdomain.com" \
  --subject-alternative-names "*.dev.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-dev
```

**Staging:**
```bash
aws acm request-certificate \
  --domain-name "staging.yourdomain.com" \
  --subject-alternative-names "*.staging.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-staging
```

**Production:**
```bash
aws acm request-certificate \
  --domain-name "yourdomain.com" \
  --subject-alternative-names "*.yourdomain.com" "www.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1 \
  --profile btg-prod
```

### Validate Certificate

1. **Go to ACM Console** → Certificate Manager
2. **Copy DNS validation records** (CNAME name and value)
3. **Add to your domain DNS** (Route53 or external DNS provider)
4. **Wait 5-10 minutes** for validation
5. **Status changes to "Issued"**
6. **Copy certificate ARN**: `arn:aws:acm:us-east-1:123456789:certificate/abc-123`

### Add Certificate to Terraform

Create `terraform.tfvars` in each environment folder:

**env-dev/terraform.tfvars** (optional):
```hcl
certificate_arn = ""  # Leave empty for HTTP-only dev
```

**env-staging/terraform.tfvars**:
```hcl
certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/abc-staging"
```

**env-prod/terraform.tfvars**:
```hcl
certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/abc-prod"
```

### What It Enables

**With Certificate:**
- ✅ Public ALB serves HTTPS on port 443
- ✅ HTTP (port 80) automatically redirects to HTTPS
- ✅ CloudFront uses custom domain with SSL
- ✅ Browser shows padlock icon (secure)

**Without Certificate (dev only):**
- ❌ HTTP only on port 80
- ❌ CloudFront uses default AWS domain

### Important Notes

- **Region must be us-east-1** - Required for CloudFront, works for ALB
- **DNS validation recommended** - Faster than email validation
- **One certificate per AWS account** - Create in each account separately
- **Zero cost** - ACM certificates are always free for AWS services

---

## Pre-Deployment Checklist

**Per AWS Account:**
- [ ] DocumentDB password created in Secrets Manager
- [ ] ACM certificate requested (staging/prod)
- [ ] DNS validation records added
- [ ] Certificate status: "Issued"
- [ ] Certificate ARN added to `terraform.tfvars`
- [ ] S3 backend bucket created (from main README)
- [ ] DynamoDB lock table created (from main README)

Now you're ready to run Terraform!

### Viewing the Secret (if needed)
```powershell
aws secretsmanager get-secret-value `
    --secret-id "docdb/btg-dev/master-password" `
    --region us-east-1 `
    --query SecretString `
    --output text | ConvertFrom-Json
```
