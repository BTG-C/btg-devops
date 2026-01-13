# Multi-Account Terraform Structure

## Overview

BTG uses **separate AWS accounts** for dev and production environments:
- **Dev Account**: Development and testing
- **Prod Account**: Staging and production environments

This structure provides:
- ✅ **Blast radius isolation**: Dev issues can't affect production
- ✅ **Cost tracking**: Separate billing per account
- ✅ **Security compliance**: Production data isolated
- ✅ **State isolation**: Terraform state stored per account

---

## Directory Structure

```
infrastructure/terraform/
├── backend-setup/           # One-time setup for remote state
│   ├── README.md
│   ├── dev/                # Creates S3+DynamoDB in dev account
│   └── prod/               # Creates S3+DynamoDB in prod account
│
├── modules/
│   └── shared-mfe/         # Reusable infrastructure module
│       ├── main.tf
│       ├── variables.tf
│       ├── s3.tf           # S3 bucket resources
│       ├── cloudfront.tf   # CloudFront distributions
│       ├── iam.tf          # IAM roles for GitHub Actions
│       ├── ssm.tf          # SSM parameters for blue-green
│       ├── locals.tf       # Data sources
│       ├── outputs.tf      # Output values
│       └── versions.tf     # Provider versions
│
├── env-dev/                # Development environment
│   ├── main.tf            # Calls shared-mfe module
│   ├── variables.tf       # Input variables
│   └── terraform.tfvars   # Dev-specific values
│
├── env-staging/            # Staging environment (prod account)
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
└── env-prod/               # Production environment (prod account)
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars
```

---

## Deployment Workflow

### 1. One-Time Backend Setup

**Run this ONCE per AWS account:**

```powershell
# Setup dev account backend
aws configure --profile btg-dev
cd c:\Git\btg-devops\infrastructure\terraform\backend-setup\dev
terraform init
terraform apply

# Setup prod account backend (used by staging + prod)
aws configure --profile btg-prod
cd c:\Git\btg-devops\infrastructure\terraform\backend-setup\prod
terraform init
terraform apply
```

This creates:
- S3 bucket for storing Terraform state
- DynamoDB table for state locking

**Cost**: <$1/month per account

---

### 2. Deploy to Development

```powershell
# Authenticate to dev AWS account
aws configure --profile btg-dev

# Navigate to dev environment
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Initialize (connects to remote state backend)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

**Output:**
```
s3_bucket_name              = "btg-dev-blue"
cloudfront_distribution_id  = "E1ABC2DEF3GHI"
cloudfront_url             = "https://d1abc2def3ghi.cloudfront.net"
github_actions_role_arn    = "arn:aws:iam::123456789012:role/btg-dev-github-actions-role"
```

---

### 3. Deploy to Staging

```powershell
# Authenticate to prod AWS account
aws configure --profile btg-prod

# Navigate to staging environment
cd c:\Git\btg-devops\infrastructure\terraform\env-staging

terraform init
terraform plan
terraform apply
```

---

### 4. Deploy to Production

```powershell
# Same prod AWS account as staging
aws configure --profile btg-prod

# Navigate to production environment
cd c:\Git\btg-devops\infrastructure\terraform\env-prod

terraform init
terraform plan
terraform apply
```

---

## Account Mapping

| Environment | AWS Account | State Bucket | Resources Created |
|-------------|-------------|--------------|-------------------|
| **dev** | Dev Account (111111111111) | `btg-terraform-state-dev` | S3, CloudFront, IAM |
| **staging** | Prod Account (222222222222) | `btg-terraform-state-prod` | S3 (blue+green), CloudFront (blue+green), IAM, SSM |
| **prod** | Prod Account (222222222222) | `btg-terraform-state-prod` | S3 (blue+green), CloudFront (blue+green), IAM, SSM |

**Note**: Staging and prod share the same AWS account but have:
- Separate state files in S3 (`staging/terraform.tfstate` vs `prod/terraform.tfstate`)
- Separate resources (different bucket names, CloudFront distributions)
- Different access controls (production has stricter IAM policies)

---

## Benefits of This Structure

### 1. **Separate AWS Accounts**
- ✅ Dev issues can't affect production AWS resources
- ✅ Separate billing for cost tracking
- ✅ Different IAM policies per account

### 2. **Reusable Module**
- ✅ DRY principle: Infrastructure code written once
- ✅ Consistent deployments across environments
- ✅ Easy to add new environments (e.g., `env-qa/`)

### 3. **Remote State**
- ✅ Team collaboration: Multiple people can run Terraform
- ✅ State locking: Prevents concurrent modifications
- ✅ Version history: Can restore previous states
- ✅ Encrypted at rest in S3

### 4. **Environment Isolation**
- ✅ Each environment has its own state file
- ✅ Changes in dev don't affect staging/prod
- ✅ Can destroy dev infrastructure without risk

---

## Adding a New Environment

To add a new environment (e.g., QA):

```powershell
# Copy existing environment
cd c:\Git\btg-devops\infrastructure\terraform
Copy-Item -Recurse env-dev env-qa

# Update values
# Edit env-qa/terraform.tfvars:
#   environment = "qa"
#   github_repo = "BTG-C/btg-*-mfe"

# Update backend in env-qa/main.tf:
#   key = "mfe-infrastructure/qa/terraform.tfstate"

# Deploy
cd env-qa
terraform init
terraform apply
```

---

## Disaster Recovery

### Restore Previous State

```powershell
# List state versions
aws s3api list-object-versions `
  --bucket btg-terraform-state-prod `
  --prefix mfe-infrastructure/prod/terraform.tfstate

# Download specific version
aws s3api get-object `
  --bucket btg-terraform-state-prod `
  --key mfe-infrastructure/prod/terraform.tfstate `
  --version-id <VERSION_ID> `
  terraform.tfstate.backup
```

### Migrate State Between Accounts

```powershell
# Export from old account
cd env-prod
terraform state pull > terraform.tfstate.backup

# Import to new account
cd ../env-prod-new-account
terraform init
terraform state push terraform.tfstate.backup
```

---

## 2026 Compliance

This structure follows **2026 infrastructure best practices**:

✅ **Infrastructure as Code**: All resources defined in Terraform  
✅ **Multi-account isolation**: Dev and prod in separate AWS accounts  
✅ **Remote state management**: S3 + DynamoDB locking  
✅ **Reusable modules**: DRY principle, consistent deployments  
✅ **Environment parity**: Same infrastructure code for all environments  
✅ **State versioning**: Can rollback infrastructure changes  
✅ **Least privilege**: Separate IAM roles per environment  

---

## Quick Reference

| Task | Command |
|------|---------|
| Setup backend (dev) | `cd backend-setup/dev; terraform apply` |
| Setup backend (prod) | `cd backend-setup/prod; terraform apply` |
| Deploy to dev | `cd env-dev; terraform apply` |
| Deploy to staging | `cd env-staging; terraform apply` |
| Deploy to prod | `cd env-prod; terraform apply` |
| View current state | `terraform show` |
| List resources | `terraform state list` |
| Destroy environment | `terraform destroy` |
| Update module | Edit `modules/shared-mfe/`, then `terraform apply` in env folders |

---

## Next Steps

1. ✅ Complete backend setup (see `backend-setup/README.md`)
2. ✅ Deploy to dev environment
3. ✅ Test GitHub Actions workflows
4. ✅ Deploy to staging
5. ✅ Deploy to production with approvals

See [AWS-SETUP.md](./AWS-SETUP.md) for detailed deployment instructions.
