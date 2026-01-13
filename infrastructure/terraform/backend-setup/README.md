# Terraform Backend Setup

This directory contains one-time setup scripts for creating S3 buckets and DynamoDB tables to store Terraform state remotely.

## Why Remote State?

- **Separate AWS Accounts**: Dev and Prod use different AWS accounts, so state must be isolated
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
cd c:\Git\btg-devops\infrastructure\terraform\backend-setup\dev
terraform init
terraform plan
terraform apply
```

**Output:**
```
state_bucket = "btg-terraform-state-dev"
lock_table   = "btg-terraform-locks-dev"
```

### 2. Setup Production Account Backend

```powershell
# Authenticate to PROD AWS account
aws configure --profile btg-prod

# Create state backend infrastructure
cd c:\Git\btg-devops\infrastructure\terraform\backend-setup\prod
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
