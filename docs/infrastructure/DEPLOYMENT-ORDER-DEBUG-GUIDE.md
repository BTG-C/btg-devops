# BTG Infrastructure - Deployment Order & Debugging Guide

**Last Updated**: January 23, 2026  
**Environments**: Dev, Staging, Production  
**Status**: ✅ **READY FOR DEPLOYMENT**

---

## Table of Contents
1. [Resource Creation Order](#resource-creation-order)
2. [Prerequisites Checklist](#prerequisites-checklist)
3. [Deployment Steps](#deployment-steps)
4. [Common Failure Scenarios](#common-failure-scenarios)
5. [Validation Commands](#validation-commands)
6. [Rollback Procedures](#rollback-procedures)
7. [Cost Estimates](#cost-estimates)

---

## Resource Creation Order

```
1. Data Source: aws_route53_zone (conditional)
   ↓
2. Networking Module (VPC, Subnets, IGW, NAT)
   ↓
3. ACM Certificate Module (conditional, DNS validation: 20-30 mins)
   ↓
4. ECS Platform Module (Cluster, ALBs, Security Groups)
   ↓
5. DocumentDB Module (Database Cluster)
   ↓
6. MFE S3 Module (Asset Storage)
   ↓
7. MFE CloudFront Module (CDN Distribution: 15-20 mins)
   ↓
8. Route53 Module (DNS Records)
   ↓
9. MFE IAM Module (GitHub Actions OIDC)
   ↓
10. Gateway Service (ECS Service)
   ↓
11. Auth Service (ECS Service)
   ↓
12. Score-Odd Service (ECS Service)
   ↓
13. Enhancer Service (ECS Service)
   ↓
14. Budget Module (Cost Monitoring)
```

---

## Prerequisites Checklist

### ⚠️ Complete Before First Deployment

#### 1. One-Time Backend Setup (Per AWS Account)

**Purpose**: Create S3 bucket and DynamoDB table for Terraform state management

```powershell
# For Development Account
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\dev
terraform init && terraform apply

# For Staging/Production Accounts - see infra-setup-pre-terraform/README.md
```

**What Gets Created**: S3 bucket (versioned, encrypted) + DynamoDB table (state locking)

> **📚 Full Documentation**: `infrastructure/terraform/infra-setup-pre-terraform/README.md`

#### 2. Create DocumentDB Passwords (Automated)

**Purpose**: Generate secure passwords stored in AWS Secrets Manager (never in Terraform state)

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform

# Run for each environment
.\create-db-secrets.ps1 -Environment dev
.\create-db-secrets.ps1 -Environment staging
.\create-db-secrets.ps1 -Environment prod
```

**Creates**: `docdb/btg-{env}/master-password` + database-specific passwords

> **📚 Full Documentation**: `infrastructure/terraform/infra-setup-pre-terraform/README-DB-SECRETS.md`

#### 3. Verify Prerequisites Complete

```bash
# Check backend exists
aws s3 ls | grep btg-terraform-state-dev
aws dynamodb describe-table --table-name btg-terraform-locks-dev

# Check secrets exist (should return 3)
aws secretsmanager list-secrets \
  --filter Key="name",Values="docdb/btg-dev" \
  --region us-east-1 \
  | jq '.SecretList | length'
```

#### 4. Optional: Custom Domain Setup

**If using custom domain** (`enable_custom_domain = true`):

1. Verify Route53 hosted zone exists for your domain
2. Request ACM certificate in us-east-1 region
3. Add DNS validation records
4. Copy certificate ARN to `terraform.tfvars`

> **📚 Certificate Documentation**: `infrastructure/terraform/infra-setup-pre-terraform/README-DB-SECRETS.md` (Section 2)

---

## Deployment Steps

### Phase 1: Initial Deployment (Without Custom Domain) - Recommended First

This deploys infrastructure WITHOUT ACM certificate and custom domain (faster, fewer points of failure):

```bash
cd infrastructure/terraform/env-dev

# 1. Initialize Terraform (downloads providers, configures backend)
terraform init

# 2. Validate syntax and configuration
terraform validate

# 3. Review planned changes
terraform plan -out=dev.tfplan

# 4. Apply all resources (takes ~15-20 minutes)
terraform apply dev.tfplan
```

**What Gets Created**:
- VPC with 2 public + 2 private subnets (NAT disabled for dev)
- ECS Cluster + Public/Internal ALBs
- DocumentDB cluster (1 instance for dev)
- S3 bucket for MFE assets
- CloudFront distribution (no custom domain)
- 4 ECS services (gateway, auth, score-odd, enhancer)
- Budget alerts

**Access Points After Deployment**:
- Public ALB: `http://<alb-dns-name>` (returns 404 - expected)
- CloudFront: `https://<distribution-id>.cloudfront.net` (serves MFE)

### Phase 2: Enable Custom Domain (Optional)

Once Phase 1 is stable, enable custom domain:

```bash
cd infrastructure/terraform/env-dev

# 1. Update terraform.tfvars
cat >> terraform.tfvars <<EOF
enable_custom_domain = true
subdomain = "dev"  # Creates dev.puntedge.com
root_domain = "puntedge.com"
EOF

# 2. Plan changes (ACM certificate + Route53 records)
terraform plan

# 3. Apply (takes 35-50 minutes due to DNS validation)
terraform apply
```

**What Gets Added**:
- ACM Certificate for `dev.puntedge.com` (DNS validation: 20-30 mins)
- Route53 A record pointing to CloudFront
- CloudFront updated with custom domain
- Public ALB updated with HTTPS listener + SSL termination

**Access Points After Custom Domain**:
- Custom domain: `https://dev.puntedge.com`

### Phase 3: Targeted Deployment (If Phase 1/2 Fails)

Deploy modules incrementally to isolate issues:

```bash
# Deploy in order
terraform apply -target=module.networking
terraform apply -target=module.ecs_platform
terraform apply -target=module.documentdb
terraform apply -target=module.mfe_s3
terraform apply -target=module.mfe_cloudfront
terraform apply -target=module.gateway_service
terraform apply  # Apply remaining resources
```

---

## Common Failure Scenarios

### 1. ❌ Backend State Lock Error
**Error**:
```
Error: Error acquiring the state lock
ConditionalCheckFailedException: The conditional request failed
```

**Root Cause**: Backend not created OR previous operation didn't complete

**Fix Option 1** - Backend doesn't exist:
```powershell
# Create backend (one-time setup)
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform\dev
terraform init && terraform apply

# Return to environment and deploy
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform init && terraform apply
```

**Fix Option 2** - Lock exists from failed run:
```bash
# Force unlock (use lock ID from error message)
terraform force-unlock <LOCK_ID>
```

> **📚 Backend Setup**: `infrastructure/terraform/infra-setup-pre-terraform/README.md`

### 2. ❌ Secrets Manager Secret Not Found
**Error**:
```
Error: error reading Secrets Manager Secret
ResourceNotFoundException: Secrets Manager can't find the specified secret
```

**Root Cause**: Required secrets not created before deployment

**Fix**:
```powershell
# Use automated script (creates master + database passwords)
cd c:\Git\btg-devops\infrastructure\terraform\infra-setup-pre-terraform
.\create-db-secrets.ps1 -Environment dev

# Then retry terraform
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform apply
```

> **📚 Full Documentation**: `infrastructure/terraform/infra-setup-pre-terraform/README-DB-SECRETS.md`

### 3. ❌ ACM Certificate Validation Timeout
**Error**:
```
Error: error waiting for ACM Certificate validation: timeout while waiting for state to become 'ISSUED'
```

**Root Cause**: 
- DNS propagation taking longer than 45 minutes (rare)
- Route53 validation records not created
- Wrong hosted zone ID

**Debug**:
```bash
# 1. Check certificate status
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --region us-east-1 \
  | jq '.Certificate.Status'

# 2. Check validation records exist in Route53
aws route53 list-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  | jq '.ResourceRecordSets[] | select(.Type == "CNAME" and (.Name | contains("_acme")))'

# 3. Test DNS resolution (may take time to propagate)
dig @8.8.8.8 _<validation-record-name> CNAME
```

**Fix**:
```bash
# Option 1: Wait and retry (usually resolves within 45 mins)
terraform apply  # Will continue from where it stopped

# Option 2: If > 60 minutes, destroy and recreate certificate
terraform destroy -target=module.acm_certificate
terraform apply -target=module.acm_certificate
```

### 4. ❌ ECS Service Fails to Stabilize
**Error**:
```
Error: waiting for ECS Service (punt-btg-dev-gateway-service) to reach a steady state: timeout
```

**Root Cause**: 
- Container crashes on startup
- Health check failing continuously
- Wrong container port mapping
- Security group blocking ALB → ECS traffic
- NAT Gateway disabled, can't pull Docker images

**Debug**:
```bash
# 1. Check service events (last 5)
aws ecs describe-services \
  --cluster punt-btg-dev-cluster \
  --services punt-btg-dev-gateway-service \
  --region us-east-1 \
  | jq '.services[0].events[:5]'

# 2. Check task status
aws ecs list-tasks --cluster punt-btg-dev-cluster --service-name punt-btg-dev-gateway-service
aws ecs describe-tasks --cluster punt-btg-dev-cluster --tasks <TASK_ARN> \
  | jq '.tasks[0].stoppedReason'

# 3. Check container logs
aws logs tail /ecs/punt-btg-dev-gateway-service --follow --region us-east-1

# 4. Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

**Fix**:
```bash
# If using nginx placeholder (expected in dev)
# Health check failures are NORMAL - services won't be "healthy" but deployment succeeds

# If need to fix:
# - Enable NAT Gateway for image pulling
# - Fix container image/port
# - Adjust health check path/timeout
terraform apply -target=module.gateway_service
```

### 5. ❌ NAT Gateway Disabled - Can't Pull Docker Images
**Error**:
```
CannotPullContainerError: Error response from daemon: Get "https://registry-1.docker.io/v2/": dial tcp: lookup registry-1.docker.io: no such host
```

**Root Cause**: `enable_nat_gateway = false` in dev environment - ECS tasks in private subnets can't reach internet

**Fix Options**:

**Option 1** - Enable NAT Gateway (costs $33/month):
```terraform
# env-dev/terraform.tfvars
enable_nat_gateway = true
```

**Option 2** - Use VPC Endpoints (FREE, best for cost optimization):
```terraform
# Add to modules/networking/main.tf
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}
```

**Option 3** - Assign Public IPs (NOT recommended for production):
```terraform
# modules/ecs-service/main.tf
network_configuration {
  assign_public_ip = true  # Tasks get public IPs
}
```

### 6. ❌ CloudFront Distribution Creation Slow
**Not an Error** - CloudFront deploys globally to 400+ edge locations

**Status Check**:
```bash
# Check distribution status (takes 15-20 minutes)
aws cloudfront get-distribution \
  --id <DISTRIBUTION_ID> \
  --region us-east-1 \
  | jq '.Distribution.Status'

# Status: "InProgress" → "Deployed"
```

### 7. ❌ Route53 Record Already Exists
**Error**:
```
Error: error creating Route53 Record
InvalidChangeBatch: RRSet of type A with DNS name dev.puntedge.com. already exists
```

**Root Cause**: DNS record already exists from previous deployment

**Fix**:
```bash
# Option 1: Import existing record
terraform import module.route53.aws_route53_record.mfe[0] <ZONE_ID>_dev.puntedge.com_A

# Option 2: Delete existing record
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://delete-record.json
```

### 8. ⚠️ Budget Alert Not Received
**Not an Error** - Budget alerts only trigger when threshold is breached or forecasted

**Verify**:
```bash
# Check budget exists
aws budgets describe-budget \
  --account-id <ACCOUNT_ID> \
  --budget-name punt-btg-dev-monthly-budget

# Check SNS subscription (confirm email subscription in inbox)
```

---

## Validation Commands

### Pre-Deployment Validation
```bash
# 1. Verify AWS credentials
aws sts get-caller-identity

# 2. Check backend exists (one-time setup)
aws s3 ls | grep btg-terraform-state-dev
aws dynamodb describe-table --table-name btg-terraform-locks-dev

# 3. Verify secrets exist (should return 3)
aws secretsmanager list-secrets \
  --filter Key="name",Values="docdb/btg-dev" \
  --region us-east-1 \
  | jq '.SecretList | length'

# 4. Validate Terraform
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform validate

# 5. Preview changes
terraform plan -out=dev.tfplan
```

### Post-Deployment Validation
```bash
# 1. Verify core infrastructure
aws ecs describe-clusters --clusters btg-dev-cluster --region us-east-1
aws docdb describe-db-clusters --db-cluster-identifier btg-dev-cluster --region us-east-1

# 2. Test endpoints
curl -I http://<ALB_DNS_NAME>  # Should return 404 (no rules configured - expected)
curl -I https://<CLOUDFRONT_URL>  # Should return 403/404 (no content - expected)

# 3. Check ECS services running
aws ecs list-services --cluster btg-dev-cluster --region us-east-1

# 4. List all created resources
terraform state list
```

---

## Rollback Procedures

### Full Environment Rollback
```bash
cd infrastructure/terraform/env-dev

# WARNING: This destroys EVERYTHING - databases, buckets, services
terraform destroy

# Confirm destruction
# Type: yes
```

### Partial Rollback (Specific Module)
```bash
# Destroy specific module (and dependent resources)
terraform destroy -target=module.gateway_service
terraform destroy -target=module.enhancer_service
terraform destroy -target=module.documentdb

# Re-apply if needed
terraform apply -target=module.documentdb
```

### Manual Resource Cleanup (If Terraform Fails)
```bash
# ECS Services
aws ecs delete-service \
  --cluster punt-btg-dev-cluster \
  --service punt-btg-dev-gateway-service \
  --force \
  --region us-east-1

# DocumentDB Cluster (skip final snapshot for dev)
aws docdb delete-db-cluster \
  --db-cluster-identifier punt-btg-dev-cluster \
  --skip-final-snapshot \
  --region us-east-1

# CloudFront Distribution (must disable first, takes 15 mins)
aws cloudfront update-distribution \
  --id <DISTRIBUTION_ID> \
  --if-match <ETAG> \
  --distribution-config file://disabled-config.json

aws cloudfront delete-distribution \
  --id <DISTRIBUTION_ID> \
  --if-match <NEW_ETAG>
```

### State Recovery (If State Corrupted)
```bash
# 1. Backup current state
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. Remove problematic resource from state
terraform state rm module.documentdb.aws_docdb_cluster.main

# 3. Re-import existing resource
terraform import module.documentdb.aws_docdb_cluster.main punt-btg-dev-cluster

# 4. Verify state
terraform plan  # Should show no changes if import successful
```

### Rollback Custom Domain Only
```bash
# Disable custom domain (faster than full destroy)
cat > terraform.tfvars <<EOF
enable_custom_domain = false
EOF

terraform apply  # Removes ACM cert, Route53 records
```

---

## Cost Estimates

### Development Environment (Optimized)
| Resource | Configuration | Monthly Cost | Notes |
|----------|---------------|--------------|-------|
| **Compute** |
| NAT Gateway | Disabled | **$0** | ✅ Saved $33/month |
| ECS Fargate | Gateway: 0.5 vCPU, 1 GB | ~$18 | 730 hrs/month |
| ECS Fargate | Auth: 0.25 vCPU, 0.5 GB | ~$11 | 730 hrs/month |
| ECS Fargate | Score-Odd: 0.5 vCPU, 1 GB | ~$18 | 730 hrs/month |
| ECS Fargate | Enhancer: 0.5 vCPU, 1 GB | ~$18 | 730 hrs/month |
| **Database** |
| DocumentDB | db.t4g.medium x 1 instance | ~$60 | ARM-based, single node |
| **Networking** |
| ALB | 2 load balancers (public + internal) | ~$32 | $16 each + data transfer |
| **Storage & CDN** |
| S3 | Versioned, lifecycle rules | <$1 | Low traffic assumption |
| CloudFront | Standard, PriceClass_100 | ~$1 | First 10 TB free tier |
| **DNS & Security** |
| Route53 | 1 hosted zone | $0.50 | Per zone per month |
| Secrets Manager | 4 secrets | ~$2 | $0.40 per secret |
| ACM Certificate | SSL/TLS | **$0** | Free for public certs |
| **Monitoring** |
| CloudWatch Logs | 7-day retention | ~$5 | Depends on log volume |
| Container Insights | ECS cluster metrics | Included | No extra charge |
| Budget Alerts | 1 budget | **$0** | First 2 budgets free |
| **TOTAL** | | **~$195-215/month** | Without NAT Gateway |

**With NAT Gateway**: ~$230-245/month (+$33)

### Staging Environment (Production-Like)
| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| NAT Gateway | 1 NAT Gateway | $33 |
| ECS Fargate | 4 services (0.5 vCPU, 1 GB) | ~$60 |
| DocumentDB | db.t4g.medium x 2 instances | ~$120 |
| ALB | 2 load balancers | ~$32 |
| S3 + CloudFront | Moderate traffic | ~$5 |
| Route53 + Secrets | 1 zone + 4 secrets | $2.50 |
| CloudWatch | 7-day retention | ~$10 |
| **TOTAL** | | **~$260-280/month** |

### Production Environment (High Availability)
| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| NAT Gateway | 2 NAT Gateways (multi-AZ) | $66 |
| ECS Fargate | 4 services (1 vCPU, 2 GB, 2 tasks each) | ~$240 |
| DocumentDB | db.r6g.large x 3 instances | ~$480 |
| ALB | 2 load balancers (high traffic) | ~$50 |
| S3 + CloudFront | High traffic | ~$20 |
| Route53 + Secrets | 1 zone + 4 secrets | $2.50 |
| CloudWatch | 30-day retention | ~$30 |
| **TOTAL** | | **~$890-920/month** |

### Cost Optimization Tips
1. **Dev**: Keep NAT disabled, use VPC endpoints (free)
2. **Staging**: Scale down to 1 DocumentDB instance during off-hours
3. **Prod**: Use Savings Plans for Fargate (30-50% discount)
4. **All**: Enable S3 lifecycle rules (already configured)
5. **All**: Set appropriate CloudWatch log retention (7 days dev, 30 days prod)

---

## Success Criteria

### ✅ Deployment Successful When:
1. `terraform apply` completes without errors (exit code 0)
2. All modules show "Apply complete! Resources: X added, 0 changed, 0 destroyed"
3. ECS cluster exists with 4 services registered
4. DocumentDB cluster status = "available"
5. CloudFront distribution status = "Deployed"
6. Public ALB accessible via HTTP (returns 404 is OK - no rules configured yet)
7. CloudFront URL accessible (returns 403/404 is OK - no content uploaded yet)
8. No critical errors in CloudWatch logs

### ⚠️ Expected Behaviors (Not Failures):
- ECS health checks may fail (placeholder images)
- ALB returns 404 (no rules configured yet)
- CloudFront returns 403/404 (no assets uploaded yet)
- ACM validation takes 20-30 minutes
- Budget alerts only when threshold breached



---

## Summary

### Current Infrastructure Status
- **Architecture**: ✅ Production-ready, well-architected
- **Security**: ✅ Strong (encryption, network isolation, secrets management)
- **Robustness**: ✅ Multi-AZ, health checks, backups
- **Cost**: ✅ Optimized ($130-150/month dev, $890-920/month prod)

### Deployment Time Estimates
- **Without custom domain**: 15-20 minutes
- **With custom domain**: 35-50 minutes (ACM validation: 20-30 mins)
- **CloudFront distribution**: 15-20 minutes (global deployment)

---

**Last Updated**: January 23, 2026  
**Reviewed By**: Infrastructure Team  
**Status**: ✅ **APPROVED FOR DEPLOYMENT**
