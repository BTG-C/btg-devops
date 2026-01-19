# DocumentDB Password Setup

## Overview

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

### Viewing the Secret (if needed)
```powershell
aws secretsmanager get-secret-value `
    --secret-id "docdb/btg-dev/master-password" `
    --region us-east-1 `
    --query SecretString `
    --output text | ConvertFrom-Json
```
