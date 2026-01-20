# AWS Prerequisites - Complete Setup Guide

## Overview

This guide covers all **manual steps** required before running Terraform to deploy the BTG MFE infrastructure to AWS.

**Time Estimate**: 30-45 minutes for first-time setup  
**Required Access**: AWS account with billing enabled

---

## Prerequisites Checklist

```
☐ 1. Create AWS account (or use existing)
☐ 2. Create IAM user: terraform-admin (with appropriate permissions)
☐ 3. Save Access Key ID and Secret Access Key securely
☐ 4. Install AWS CLI
☐ 5. Configure AWS CLI (aws configure)
☐ 6. Verify AWS credentials work
☐ 7. Install Terraform CLI
☐ 8. Create GitHub OIDC provider (once per AWS account)
☐ 9. (Optional) Request SSL certificate for custom domain
☐ 10. (Optional) Setup remote state backend (S3 + DynamoDB)
```

---

## Step 1: AWS Account Creation

### Create New AWS Account

1. **Navigate to AWS**  
   Go to https://aws.amazon.com/

2. **Click "Create an AWS Account"**

3. **Provide Account Details**:
   - Email address
   - Password
   - AWS account name (e.g., "BTG Production")

4. **Add Payment Method**:
   - Credit card required (even for free tier)
   - You won't be charged unless you exceed free tier limits

5. **Verify Identity**:
   - Phone verification
   - Automated call or SMS

6. **Choose Support Plan**:
   - Select "Basic Support - Free" (sufficient for most use cases)

7. **Wait for Activation**:
   - Usually takes 5-10 minutes
   - Check email for confirmation

### Sign In to AWS Console

```
URL: https://console.aws.amazon.com/
Account ID or alias: <your-account-id>
IAM user name: (not yet created)
```

---

## Step 2: Create IAM User for Terraform

### Why IAM User?

- **Best Practice**: Never use root account credentials
- **Security**: Limit permissions to what Terraform needs
- **Auditing**: Track which actions Terraform performs

### Option A: AWS Console (Recommended for Beginners)

1. **Sign in to AWS Console** as root user

2. **Navigate to IAM**:
   - Search "IAM" in top search bar
   - Click "IAM" service

3. **Create User**:
   - Left sidebar: Click "Users"
   - Click "Add users" button
   - Username: `terraform-admin`
   - Click "Next"

4. **Set Permissions**:
   - Select "Attach policies directly"
   - Search and select: `AdministratorAccess`
   - ⚠️ For production, use custom policy (see below)
   - Click "Next"

5. **Review and Create**:
   - Review settings
   - Click "Create user"

6. **Create Access Key**:
   - Click on the newly created user
   - Go to "Security credentials" tab
   - Scroll to "Access keys"
   - Click "Create access key"
   - Select use case: "Command Line Interface (CLI)"
   - Check acknowledgment box
   - Click "Next"
   - Add description: "Terraform CLI access"
   - Click "Create access key"

7. **Save Credentials** (CRITICAL):
   ```
   Access Key ID: AKIAIOSFODNN7EXAMPLE
   Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   ```
   - Download .csv file
   - Store securely (password manager, vault)
   - ⚠️ You cannot retrieve Secret Access Key again!

### Option B: AWS CLI (If You Have Root Access)

```powershell
# Create IAM user
aws iam create-user --user-name terraform-admin

# Attach administrator access policy
aws iam attach-user-policy `
  --user-name terraform-admin `
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access key
aws iam create-access-key --user-name terraform-admin
```

**Save the output**:
```json
{
    "AccessKey": {
        "UserName": "terraform-admin",
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "Status": "Active",
        "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        "CreateDate": "2025-12-26T10:00:00Z"
    }
}
```

### Custom IAM Policy (Production-Ready)

For least privilege access, create custom policy instead of `AdministratorAccess`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformS3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketPolicy",
        "s3:GetBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetPublicAccessBlock",
        "s3:ListBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutPublicAccessBlock"
      ],
      "Resource": [
        "arn:aws:s3:::btg-*",
        "arn:aws:s3:::btg-*/*"
      ]
    },
    {
      "Sid": "TerraformCloudFrontPermissions",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:CreateResponseHeadersPolicy",
        "cloudfront:DeleteDistribution",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:DeleteResponseHeadersPolicy",
        "cloudfront:GetDistribution",
        "cloudfront:GetOriginAccessControl",
        "cloudfront:GetResponseHeadersPolicy",
        "cloudfront:ListDistributions",
        "cloudfront:ListOriginAccessControls",
        "cloudfront:ListResponseHeadersPolicies",
        "cloudfront:TagResource",
        "cloudfront:UpdateDistribution",
        "cloudfront:UpdateOriginAccessControl",
        "cloudfront:UpdateResponseHeadersPolicy"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformIAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:CreatePolicy",
        "iam:DeleteRole",
        "iam:DeletePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetOpenIDConnectProvider",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:PutRolePolicy",
        "iam:TagRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::*:role/btg-*",
        "arn:aws:iam::*:policy/btg-*",
        "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      "Sid": "TerraformSSMPermissions",
      "Effect": "Allow",
      "Action": [
        "ssm:AddTagsToResource",
        "ssm:DeleteParameter",
        "ssm:GetParameter",
        "ssm:PutParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/btg/*"
    },
    {
      "Sid": "TerraformACMPermissions",
      "Effect": "Allow",
      "Action": [
        "acm:DescribeCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "*"
    }
  ]
}
```

**To apply custom policy**:
1. IAM Console → Policies → Create policy
2. JSON tab → Paste above JSON
3. Name: `TerraformBTGDeploymentPolicy`
4. Create policy
5. Attach to `terraform-admin` user

---

## Step 3: Install AWS CLI

### Windows (PowerShell)

**Option A: Using Chocolatey**
```powershell
# Install Chocolatey first (if not installed)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install AWS CLI
choco install awscli -y
```

**Option B: MSI Installer**
1. Download from: https://awscli.amazonaws.com/AWSCLIV2.msi
2. Run installer
3. Follow installation wizard
4. Restart PowerShell

**Verify Installation**:
```powershell
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x Windows/10 exe/AMD64
```

### Linux
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### macOS
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

---

## Step 4: Configure AWS CLI

### Run AWS Configure

```powershell
aws configure
```

**Enter when prompted**:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

### Configuration Files Created

**Credentials** (`~/.aws/credentials`):
```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Config** (`~/.aws/config`):
```ini
[default]
region = us-east-1
output = json
```

### Named Profiles (Optional)

If managing multiple AWS accounts:

```powershell
aws configure --profile btg-prod
aws configure --profile btg-dev
```

Use with:
```powershell
aws s3 ls --profile btg-prod
```

---

## Step 5: Verify AWS Credentials

### Test AWS CLI Access

```powershell
# Get caller identity
aws sts get-caller-identity
```

**Expected output**:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-admin"
}
```

### Test S3 Access

```powershell
# List S3 buckets (should return empty list if none exist)
aws s3 ls
```

### Test Region Configuration

```powershell
# Check configured region
aws configure get region
# Output: us-east-1
```

### Troubleshooting

**Error**: `Unable to locate credentials`
```powershell
# Re-run configure
aws configure
```

**Error**: `Access Denied`
```powershell
# Check user has correct permissions
aws iam list-attached-user-policies --user-name terraform-admin
```

---

## Step 6: Install Terraform

### Windows (PowerShell)

**Option A: Using Chocolatey**
```powershell
choco install terraform -y
```

**Option B: Manual Installation**
1. Download from: https://www.terraform.io/downloads
2. Select "Windows" → "AMD64"
3. Extract `terraform.exe` from ZIP
4. Move to: `C:\Program Files\Terraform\`
5. Add to PATH:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Terraform", "Machine")
   ```
6. Restart PowerShell

**Verify Installation**:
```powershell
terraform version
# Expected: Terraform v1.6.x or higher
```

### Linux
```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

---

## Step 7: Create GitHub OIDC Provider

### Why OIDC?

- **No static credentials** in GitHub Secrets
- **Temporary tokens** issued per workflow run
- **More secure** than long-lived access keys
- **Auditable** via AWS CloudTrail

### Create Provider (One-Time Per AWS Account)

```powershell
# Create GitHub OIDC identity provider
aws iam create-open-id-connect-provider `
  --url https://token.actions.githubusercontent.com `
  --client-id-list sts.amazonaws.com `
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Expected output**:
```json
{
    "OpenIDConnectProviderArn": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
}
```

### Verify Provider Exists

```powershell
# List OIDC providers
aws iam list-open-id-connect-providers
```

**Expected output**:
```json
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```

### Get Provider Details

```powershell
# Get provider details
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

### Important Notes

- ✅ **Create once per AWS account** (not per environment)
- ✅ **Shared across all repositories** in your organization
- ✅ **Terraform will reference this** in IAM role trust policies
- ⚠️ If already exists, skip this step (CLI will return error)

---

## Step 8: (Optional) SSL Certificate for Custom Domain

### When Do You Need This?

- Using custom domain like `app.yourcompany.com`
- Skip if using CloudFront default domain (e.g., `d123abc.cloudfront.net`)

### Request Certificate

**Must be in us-east-1 region for CloudFront**:

```powershell
# Request certificate
aws acm request-certificate `
  --region us-east-1 `
  --domain-name app.yourcompany.com `
  --validation-method DNS `
  --subject-alternative-names "*.app.yourcompany.com"
```

**Output**:
```json
{
    "CertificateArn": "arn:aws:acm:us-east-1:123456789012:certificate/abc-def-123-456"
}
```

### Validate Certificate

1. **Go to ACM Console**:
   - https://console.aws.amazon.com/acm/home?region=us-east-1
   - Click on certificate

2. **Get CNAME Records**:
   ```
   Name: _abc123.app.yourcompany.com
   Type: CNAME
   Value: _xyz456.acm-validations.aws.
   ```

3. **Add to DNS Provider**:
   - Route 53, GoDaddy, Cloudflare, etc.
   - Add the CNAME record

4. **Wait for Validation**:
   - Usually 5-30 minutes
   - Status changes to "Issued"

### Use Certificate in Terraform

Update `environments/prod.tfvars`:
```hcl
domain_name      = "app.yourcompany.com"
certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/abc-def-123-456"
```

---

## Step 9: (Optional) Remote State Backend

### Why Remote State?

- **Team collaboration** - Multiple people can run Terraform
- **State locking** - Prevents concurrent modifications
- **State versioning** - History of infrastructure changes
- **Security** - Encrypted state in S3

### Create S3 Bucket for State

```powershell
# Create bucket (must be globally unique name)
aws s3api create-bucket `
  --bucket btg-terraform-state-123456 `
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket btg-terraform-state-123456 `
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption `
  --bucket btg-terraform-state-123456 `
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block `
  --bucket btg-terraform-state-123456 `
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

### Create DynamoDB Table for Locking

```powershell
# Create table
aws dynamodb create-table `
  --table-name btg-terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region us-east-1
```

### Configure Terraform Backend

Update `c:\Git\btg-deployment\aws-infra\main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"
  
  # Add backend configuration
  backend "s3" {
    bucket         = "btg-terraform-state-123456"
    key            = "btg-mfe/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "btg-terraform-locks"
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Initialize Backend

```powershell
cd c:\Git\btg-deployment\aws-infra
terraform init
```

---

## Verification Script

Save as `verify-aws-setup.ps1`:

```powershell
Write-Host "`n🔍 BTG AWS Prerequisites Verification`n" -ForegroundColor Cyan

$allGood = $true

# Check AWS CLI
Write-Host "Checking AWS CLI..." -NoNewline
if (Get-Command aws -ErrorAction SilentlyContinue) {
    $awsVersion = aws --version 2>&1
    Write-Host " ✅" -ForegroundColor Green
    Write-Host "   Version: $awsVersion" -ForegroundColor Gray
} else {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Install from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    $allGood = $false
}

# Check Terraform
Write-Host "Checking Terraform..." -NoNewline
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    $tfVersion = terraform version | Select-Object -First 1
    Write-Host " ✅" -ForegroundColor Green
    Write-Host "   Version: $tfVersion" -ForegroundColor Gray
} else {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Install from: https://www.terraform.io/downloads" -ForegroundColor Yellow
    $allGood = $false
}

# Check AWS credentials
Write-Host "Checking AWS credentials..." -NoNewline
try {
    $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if ($identity) {
        Write-Host " ✅" -ForegroundColor Green
        Write-Host "   Account: $($identity.Account)" -ForegroundColor Gray
        Write-Host "   User ARN: $($identity.Arn)" -ForegroundColor Gray
    } else {
        throw "No identity returned"
    }
} catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Yellow
    $allGood = $false
}

# Check GitHub OIDC provider
Write-Host "Checking GitHub OIDC provider..." -NoNewline
try {
    $providers = aws iam list-open-id-connect-providers --output json 2>$null | ConvertFrom-Json
    $githubProvider = $providers.OpenIDConnectProviderList | Where-Object { $_.Arn -like "*token.actions.githubusercontent.com*" }
    
    if ($githubProvider) {
        Write-Host " ✅" -ForegroundColor Green
        Write-Host "   ARN: $($githubProvider.Arn)" -ForegroundColor Gray
    } else {
        Write-Host " ⚠️" -ForegroundColor Yellow
        Write-Host "   Create with: aws iam create-open-id-connect-provider ..." -ForegroundColor Yellow
    }
} catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Cannot check OIDC providers" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" -NoNewline
if ($allGood) {
    Write-Host "✨ All prerequisites met! Ready to run Terraform." -ForegroundColor Green
} else {
    Write-Host "⚠️  Some prerequisites missing. Complete setup above." -ForegroundColor Yellow
}
Write-Host ""
```

**Run verification**:
```powershell
.\verify-aws-setup.ps1
```

---

## Next Steps

After completing all prerequisites:

```powershell
# 1. Navigate to Terraform directory
cd c:\Git\btg-deployment\aws-infra

# 2. Initialize Terraform
terraform init

# 3. Validate configuration
terraform validate

# 4. Plan infrastructure (see what will be created)
terraform plan -var-file="environments/dev.tfvars"

# 5. Apply infrastructure (create resources)
terraform apply -var-file="environments/dev.tfvars"
```

---

## Cost Estimates

### Free Tier Eligible (First 12 Months)

- **S3**: 5 GB storage, 20,000 GET requests, 2,000 PUT requests
- **CloudFront**: 1 TB data transfer out, 10,000,000 requests
- **IAM**: Always free
- **SSM**: Always free

### Expected Monthly Costs (After Free Tier)

**Development Environment**:
- S3: ~$2/month (10 GB storage, moderate usage)
- CloudFront: ~$5/month (100 GB transfer, 1M requests)
- **Total: ~$7/month**

**Production Environment**:
- S3: ~$3/month (15 GB storage with lifecycle policies)
- CloudFront: ~$20/month (500 GB transfer, 5M requests)
- **Total: ~$23/month**

---

## Security Best Practices

### IAM User Management

✅ **DO**:
- Use IAM users, not root account
- Enable MFA on terraform-admin user
- Rotate access keys every 90 days
- Use least privilege policies in production
- Store credentials in password manager

❌ **DON'T**:
- Commit credentials to Git
- Share access keys
- Use root account for daily operations
- Grant broader permissions than needed

### Credential Storage

**Secure storage options**:
- 1Password
- LastPass
- AWS Secrets Manager
- HashiCorp Vault
- Encrypted file with proper permissions

**Never store in**:
- Git repositories
- Unencrypted files
- Slack/email
- Public locations

---

## Troubleshooting

### AWS CLI Not Found

```powershell
# Windows: Restart PowerShell after installation
# Or add to PATH manually
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2\"
```

### Access Denied Errors

```powershell
# Check user permissions
aws iam get-user --user-name terraform-admin
aws iam list-attached-user-policies --user-name terraform-admin

# Verify you're using correct profile
aws configure list
```

### OIDC Provider Already Exists

```bash
# This is fine! Skip creation step
# Error: EntityAlreadyExists
# Solution: Continue to next step
```

### Certificate Validation Stuck

- Check DNS record was added correctly
- Wait up to 30 minutes for DNS propagation
- Verify CNAME record with: `nslookup <cname-name>`

---

## Summary

### Required Steps (Everyone)
1. ✅ AWS account
2. ✅ IAM user (terraform-admin)
3. ✅ AWS CLI installed and configured
4. ✅ Terraform installed
5. ✅ GitHub OIDC provider

### Optional Steps (As Needed)
6. ⚠️ SSL certificate (custom domains only)
7. ⚠️ Remote state backend (team collaboration)

**After completing these steps, you're ready to run Terraform!** 🚀

Proceed to: [Terraform Infrastructure Deployment](./AWS_SETUP.md)
