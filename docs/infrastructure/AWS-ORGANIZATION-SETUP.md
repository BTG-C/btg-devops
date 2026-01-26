# AWS Multi-Account Organization Setup Guide

**Purpose:** Generic guide for setting up AWS Organizations with multi-account structure for any product/application.

**Audience:** Platform teams, DevOps engineers setting up foundational AWS infrastructure

**Scope:** AWS Organizations, member account creation, consolidated billing, foundational IAM roles

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Architecture](#3-architecture)
4. [Root Account Setup](#4-root-account-setup)
5. [Create AWS Organization](#5-create-aws-organization)
6. [Create Organizational Units](#6-create-organizational-units)
7. [Create Member Accounts](#7-create-member-accounts)
8. [Configure Consolidated Billing](#8-configure-consolidated-billing)
9. [Set Up Cross-Account Access](#9-set-up-cross-account-access)
10. [Configure AWS CLI Profiles](#10-configure-aws-cli-profiles)
11. [Enable AWS CloudTrail](#11-enable-aws-cloudtrail)
12. [Cost Allocation Tags](#12-cost-allocation-tags)
13. [Verification](#13-verification)
14. [Next Steps](#14-next-steps)

---

## 1. Overview

### What is AWS Organizations?

AWS Organizations enables you to:
- **Centrally manage** multiple AWS accounts
- **Consolidate billing** across all accounts
- **Apply policies** organization-wide
- **Share resources** across accounts
- **Automate account creation**

### Multi-Account Benefits

| Benefit | Description |
|---------|-------------|
| **Isolation** | Blast radius containment per environment |
| **Security** | Separate credentials and IAM policies |
| **Compliance** | Audit trails per environment |
| **Cost Control** | Granular cost tracking and budgets |
| **Flexibility** | Independent account configurations |

### Typical Structure

```
Root Account (Management Account)
└── Organizational Units (OUs)
    ├── Engineering OU
    │   ├── Product A - Dev Account
    │   ├── Product A - Staging Account
    │   └── Product A - Production Account
    ├── Data OU
    └── Security OU
```

---

## 2. Prerequisites

### Required Items

- ✅ **Root AWS Account:** You should already have an AWS root account from initial signup (created when you first signed up for AWS). This will become your management account.
- ✅ **Email Addresses:** Unique email per member account (use `+` aliases: `aws+dev@company.com`)
  - For startups/small teams: Use `+` aliases (e.g., `aws+dev@company.com`) - all emails go to one inbox
  - For enterprises: Use separate mailboxes (e.g., `aws-dev@company.com`) - better governance and access control
- ✅ **Domain:** Company domain for email addresses
- ✅ **Credit Card:** Valid payment method on root account
- ✅ **MFA Device:** Hardware or virtual MFA for root user

### Tools Required

- AWS CLI v2+ installed
- `jq` for JSON processing (optional but recommended)
- Terminal access (bash/PowerShell)

### Knowledge Prerequisites

- Basic AWS IAM concepts
- Understanding of AWS regions
- Familiarity with AWS CLI

---

## 3. Architecture

### Account Structure

```
punt-root (Management Account)
├── aws-root@puntedge.com
├── Account ID: 123456789012
└── Purpose: Billing, organization management only (no workloads)

Engineering OU
├── punt-{product}-dev
│   ├── Email: aws-{product}-dev@puntedge.com
│   └── Purpose: Development workloads
├── punt-{product}-staging
│   ├── Email: aws-{product}-staging@puntedge.com
│   └── Purpose: Staging/QA workloads
└── punt-{product}-prod
    ├── Email: aws-{product}-prod@puntedge.com
    └── Purpose: Production workloads
```

### Naming Convention

| Resource | Pattern | Example |
|----------|---------|---------|
| **Organization** | `{company}` | `puntedge` |
| **Root Account** | `{company}-root` | `punt-root` |
| **Member Account** | `{short}-{product}-{env}` | `punt-btg-dev` |
| **OU Name** | `{department}` | `Engineering` |
| **CLI Profile** | `{short}-{product}-{env}` | `punt-btg-dev` |

---

## 4. Root Account Setup

### Step 1: Secure Root Account

```bash
# 1. Sign in to AWS Console as root user
# 2. Navigate to: IAM → Dashboard → Security Recommendations

# Enable MFA for root user
# - Go to "My Security Credentials"
# - Activate MFA → Choose Virtual/Hardware MFA
# - Scan QR code with authenticator app
# - Enter two consecutive MFA codes
```

### Step 2: Create Admin IAM User

```bash
# Create administrator user (not root) for daily operations
# 1. IAM → Users → Create user
# 2. Username: admin-{yourname}
# 3. Enable console access + programmatic access
# 4. Attach policy: AdministratorAccess
# 5. Enable MFA for this user
# 6. Download access keys
```

### Step 3: Configure AWS CLI

```bash
# Configure admin profile
aws configure --profile punt-root

# Enter:
# - AWS Access Key ID: <admin-user-key>
# - AWS Secret Access Key: <admin-user-secret>
# - Default region: us-east-1
# - Default output format: json

# Test
aws sts get-caller-identity --profile punt-root
```

---

## 5. Create AWS Organization

### Step 1: Enable AWS Organizations

```bash
# Via AWS CLI
aws organizations create-organization \
  --feature-set ALL \
  --profile punt-root

# Expected Output:
# {
#   "Organization": {
#     "Id": "o-xxxxxxxxxx",
#     "Arn": "arn:aws:organizations::123456789012:organization/o-xxxxxxxxxx",
#     "FeatureSet": "ALL",
#     "MasterAccountArn": "arn:aws:organizations::123456789012:account/o-xxxxxxxxxx/123456789012",
#     "MasterAccountId": "123456789012",
#     "MasterAccountEmail": "aws-root@puntedge.com"
#   }
# }
```

### Step 2: Verify Organization

```bash
# Check organization details
aws organizations describe-organization --profile punt-root

# List accounts (should show only root account initially)
aws organizations list-accounts --profile punt-root
```

---

## 6. Create Organizational Units

### Step 1: Get Root ID

```bash
# Get the root ID (needed for creating OUs)
ROOT_ID=$(aws organizations list-roots --profile punt-root --query 'Roots[0].Id' --output text)
echo "Root ID: $ROOT_ID"
```

### Step 2: Create Engineering OU

```bash
# Create Engineering OU
aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name "Engineering" \
  --profile punt-root

# Save the OU ID
ENGINEERING_OU_ID=$(aws organizations list-organizational-units-for-parent \
  --parent-id $ROOT_ID \
  --profile punt-root \
  --query 'OrganizationalUnits[?Name==`Engineering`].Id' \
  --output text)

echo "Engineering OU ID: $ENGINEERING_OU_ID"
```

### Step 3: Create Additional OUs (Optional)

```bash
# Create Data OU
aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name "Data" \
  --profile punt-root

# Create Security OU
aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name "Security" \
  --profile punt-root

# List all OUs
aws organizations list-organizational-units-for-parent \
  --parent-id $ROOT_ID \
  --profile punt-root
```

---

## 7. Create Member Accounts

### Step 1: Create Development Account

```bash
# Create dev account
aws organizations create-account \
  --email "aws-{product}-dev@puntedge.com" \
  --account-name "punt-{product}-dev" \
  --profile punt-root

# Check creation status (may take 5-10 minutes)
aws organizations list-accounts --profile punt-root \
  --query 'Accounts[?Name==`punt-{product}-dev`]'
```

### Step 2: Create Staging Account

```bash
# Create staging account
aws organizations create-account \
  --email "aws-{product}-staging@puntedge.com" \
  --account-name "punt-{product}-staging" \
  --profile punt-root
```

### Step 3: Create Production Account

```bash
# Create production account
aws organizations create-account \
  --email "aws-{product}-prod@puntedge.com" \
  --account-name "punt-{product}-prod" \
  --profile punt-root
```

### Step 4: Move Accounts to Engineering OU

```bash
# Get account IDs
DEV_ACCOUNT_ID=$(aws organizations list-accounts --profile punt-root \
  --query 'Accounts[?Name==`punt-{product}-dev`].Id' --output text)

STAGING_ACCOUNT_ID=$(aws organizations list-accounts --profile punt-root \
  --query 'Accounts[?Name==`punt-{product}-staging`].Id' --output text)

PROD_ACCOUNT_ID=$(aws organizations list-accounts --profile punt-root \
  --query 'Accounts[?Name==`punt-{product}-prod`].Id' --output text)

# Move accounts to Engineering OU
aws organizations move-account \
  --account-id $DEV_ACCOUNT_ID \
  --source-parent-id $ROOT_ID \
  --destination-parent-id $ENGINEERING_OU_ID \
  --profile punt-root

aws organizations move-account \
  --account-id $STAGING_ACCOUNT_ID \
  --source-parent-id $ROOT_ID \
  --destination-parent-id $ENGINEERING_OU_ID \
  --profile punt-root

aws organizations move-account \
  --account-id $PROD_ACCOUNT_ID \
  --source-parent-id $ROOT_ID \
  --destination-parent-id $ENGINEERING_OU_ID \
  --profile punt-root
```

---

## 8. Configure Consolidated Billing

### Automatic Setup

✅ **Consolidated billing is automatically enabled** when you create an AWS Organization.

### Verification

```bash
# View consolidated billing dashboard
# AWS Console → Billing → Bills
# You should see charges from all member accounts
```

### Enable Cost Allocation Tags

```bash
# Activate cost allocation tags for better tracking
# AWS Console → Billing → Cost Allocation Tags
# Activate these tags:
# - Environment
# - Product
# - CostCenter
# - Organization
```

---

## 9. Set Up Cross-Account Access

### Step 1: Create OrganizationAccountAccessRole

This role is **automatically created** in new member accounts. Verify:

```bash
# Switch to member account (we'll configure CLI profiles next)
# Then check if role exists:
aws iam get-role \
  --role-name OrganizationAccountAccessRole \
  --profile punt-{product}-dev
```

### Step 2: Create Custom Admin Role (Optional)

For more granular control, create custom roles:

```bash
# In member account, create role with trust policy for root account
# See BTG-AWS-DEPLOYMENT.md for product-specific IAM roles
```

### Step 3: Test Cross-Account Assume Role

```bash
# From root account, assume role in dev account
aws sts assume-role \
  --role-arn "arn:aws:iam::${DEV_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "test-session" \
  --profile punt-root
```

---

## 10. Configure AWS CLI Profiles

### Step 1: Access Member Accounts

**First Login (via AWS Console):**

1. Check email for each member account
2. Click "Reset Password" link in invitation email
3. Set new password for root user in each member account
4. Enable MFA for each member account root user
5. Create IAM admin user in each account (recommended)

### Step 2: Configure CLI Profiles

**Method 1: Direct Credentials (if you created IAM users)**

```bash
# Configure each environment profile
aws configure --profile punt-{product}-dev
aws configure --profile punt-{product}-staging
aws configure --profile punt-{product}-prod
```

**Method 2: Role Assumption (recommended)**

Edit `~/.aws/config`:

```ini
[profile punt-root]
region = us-east-1
output = json

[profile punt-{product}-dev]
role_arn = arn:aws:iam::${DEV_ACCOUNT_ID}:role/OrganizationAccountAccessRole
source_profile = punt-root
region = us-east-1
output = json

[profile punt-{product}-staging]
role_arn = arn:aws:iam::${STAGING_ACCOUNT_ID}:role/OrganizationAccountAccessRole
source_profile = punt-root
region = us-east-1
output = json

[profile punt-{product}-prod]
role_arn = arn:aws:iam::${PROD_ACCOUNT_ID}:role/OrganizationAccountAccessRole
source_profile = punt-root
region = us-east-1
output = json
```

### Step 3: Test Profiles

```bash
# Test each profile
aws sts get-caller-identity --profile punt-{product}-dev
aws sts get-caller-identity --profile punt-{product}-staging
aws sts get-caller-identity --profile punt-{product}-prod
```

---

## 11. Enable AWS CloudTrail

### Organization Trail (Centralized Logging)

```bash
# Create S3 bucket in root account for CloudTrail logs
aws s3 mb s3://punt-cloudtrail-logs-${ROOT_ACCOUNT_ID} --profile punt-root

# Create organization trail (logs all accounts)
aws cloudtrail create-trail \
  --name punt-organization-trail \
  --s3-bucket-name punt-cloudtrail-logs-${ROOT_ACCOUNT_ID} \
  --is-organization-trail \
  --is-multi-region-trail \
  --profile punt-root

# Start logging
aws cloudtrail start-logging \
  --name punt-organization-trail \
  --profile punt-root
```

---

## 12. Cost Allocation Tags

### Step 1: Define Standard Tags

```json
{
  "Organization": "PuntEdge",
  "Product": "{product-name}",
  "Environment": "{dev|staging|prod}",
  "CostCenter": "Engineering",
  "ManagedBy": "Terraform"
}
```

### Step 2: Activate in Billing Console

```bash
# AWS Console → Billing → Cost Allocation Tags
# Activate all tags defined above
# Wait 24 hours for tags to appear in Cost Explorer
```

---

## 13. Verification

### Checklist

```bash
# ✅ Organization created
aws organizations describe-organization --profile punt-root

# ✅ All member accounts visible
aws organizations list-accounts --profile punt-root

# ✅ Accounts in correct OU
aws organizations list-accounts-for-parent \
  --parent-id $ENGINEERING_OU_ID \
  --profile punt-root

# ✅ CLI profiles working
aws sts get-caller-identity --profile punt-{product}-dev
aws sts get-caller-identity --profile punt-{product}-staging
aws sts get-caller-identity --profile punt-{product}-prod

# ✅ CloudTrail logging
aws cloudtrail get-trail-status \
  --name punt-organization-trail \
  --profile punt-root

# ✅ Consolidated billing enabled (check AWS Console)
```

---

## 14. Next Steps

### Product-Specific Setup

Now that your AWS Organization is configured, proceed to product-specific deployment:

- **For BTG Product:** See [BTG-AWS-DEPLOYMENT.md](./BTG-AWS-DEPLOYMENT.md)
- **For Other Products:** Create similar product-specific deployment guides

### Security Hardening

- Enable AWS Config organization-wide
- Set up AWS Security Hub
- Configure AWS GuardDuty
- Implement SCPs (Service Control Policies) for guardrails

### Cost Optimization

- Set up budget alerts per account
- Enable AWS Cost Anomaly Detection
- Create cost allocation reports
- Review reserved instance opportunities

---

## Appendix: Account ID Reference

| Account | Email | Account ID | CLI Profile |
|---------|-------|------------|-------------|
| Root | `aws-root@puntedge.com` | `<root-id>` | `punt-root` |
| Dev | `aws-{product}-dev@puntedge.com` | `<dev-id>` | `punt-{product}-dev` |
| Staging | `aws-{product}-staging@puntedge.com` | `<staging-id>` | `punt-{product}-staging` |
| Production | `aws-{product}-prod@puntedge.com` | `<prod-id>` | `punt-{product}-prod` |

---

## Troubleshooting

### Issue: "Email already in use"

**Solution:** Use email aliases with `+` sign:
- `aws+root@puntedge.com`
- `aws+btg-dev@puntedge.com`

### Issue: "Cannot assume role"

**Solution:** Verify trust policy on OrganizationAccountAccessRole allows root account.

### Issue: "Account creation pending"

**Solution:** Wait 5-10 minutes. Check status:
```bash
aws organizations describe-create-account-status \
  --create-account-request-id <request-id> \
  --profile punt-root
```

---

**Document Version:** 1.0  
**Last Updated:** January 21, 2026  
**Maintained By:** Platform Team
