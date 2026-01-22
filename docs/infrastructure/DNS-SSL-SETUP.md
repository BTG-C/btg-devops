# DNS and SSL Certificate Setup Guide

## Overview

Now that `puntedge.com` is registered in Route 53, you can enable custom domains and SSL certificates for your BTG environments.

## Architecture

```
puntedge.com (Root Domain)
├── dev.btg.puntedge.com → Dev Environment
├── staging.btg.puntedge.com → Staging Environment
└── btg.puntedge.com → Production Environment
```

## Current Status

✅ **Domain Registered:** `puntedge.com` in Route 53  
✅ **Hosted Zone Created:** Automatically created during registration  
✅ **Terraform Modules Added:**
- `modules/route53` - DNS record management
- `modules/acm-certificate` - SSL certificate provisioning

## Enable Custom Domain (Step-by-Step)

### Step 1: Enable for Development Environment

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
```

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
# terraform.tfvars
enable_custom_domain = true
subdomain            = "dev.btg"
root_domain          = "puntedge.com"
```

### Step 2: Initialize and Plan

```powershell
# Initialize Terraform (if not already done)
terraform init

# Review changes
terraform plan
```

**Expected Resources:**
- 1 ACM Certificate: `dev.btg.puntedge.com`
- 3 Route 53 DNS validation records (CNAME)
- 1 ACM Certificate Validation (waits for DNS propagation)
- 1 Route 53 A record: `dev.btg.puntedge.com` → CloudFront

### Step 3: Apply Changes

```powershell
# Apply (certificate validation takes 5-30 minutes)
terraform apply

# Monitor certificate validation
terraform show | Select-String "certificate"
```

### Step 4: Verify DNS and Certificate

```powershell
# Get the custom domain URL
terraform output custom_domain_url
# Output: https://dev.btg.puntedge.com

# Test DNS resolution
nslookup dev.btg.puntedge.com

# Test HTTPS (wait 10-15 minutes for CloudFront propagation)
Invoke-WebRequest -Uri "https://dev.btg.puntedge.com"
```

## Configuration Options

### Default Configuration (Dev)

```hcl
enable_custom_domain = false  # Use CloudFront URL only
subdomain            = "dev.btg"
root_domain          = "puntedge.com"
```

**Result:** Uses CloudFront distribution URL (e.g., `d123abc.cloudfront.net`)

### With Custom Domain (Dev)

```hcl
enable_custom_domain = true
subdomain            = "dev.btg"
root_domain          = "puntedge.com"
```

**Result:**
- URL: `https://dev.btg.puntedge.com`
- ACM Certificate: Auto-provisioned and validated
- DNS: Auto-configured A record

## Environment-Specific Domains

| Environment | Subdomain | Full URL | Certificate |
|-------------|-----------|----------|-------------|
| **Dev** | `dev.btg` | `https://dev.btg.puntedge.com` | `*.dev.btg.puntedge.com` |
| **Staging** | `staging.btg` | `https://staging.btg.puntedge.com` | `*.staging.btg.puntedge.com` |
| **Production** | `btg` | `https://btg.puntedge.com` | `*.btg.puntedge.com` |

## Staging and Production Setup

### Staging

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-staging

# Create terraform.tfvars
@"
enable_custom_domain = true
subdomain            = "staging.btg"
root_domain          = "puntedge.com"
"@ | Out-File -FilePath terraform.tfvars

terraform init
terraform plan
terraform apply
```

### Production

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-prod

# Create terraform.tfvars
@"
enable_custom_domain = true
subdomain            = "btg"
root_domain          = "puntedge.com"
"@ | Out-File -FilePath terraform.tfvars

terraform init
terraform plan
terraform apply
```

## How It Works

### 1. ACM Certificate Module

```hcl
module "acm_certificate" {
  source = "../modules/acm-certificate"
  
  domain_name    = "dev.btg.puntedge.com"
  hosted_zone_id = data.aws_route53_zone.main.zone_id
}
```

**Actions:**
1. Requests ACM certificate for `dev.btg.puntedge.com`
2. Creates DNS validation CNAME records in Route 53
3. Waits for certificate validation (5-30 minutes)
4. Returns validated certificate ARN

### 2. Route 53 Module

```hcl
module "route53" {
  source = "../modules/route53"
  
  domain_name            = "puntedge.com"
  subdomain              = "dev.btg"
  cloudfront_domain_name = module.mfe_cloudfront.distribution_domain_name
}
```

**Actions:**
1. Looks up existing hosted zone for `puntedge.com`
2. Creates A record: `dev.btg.puntedge.com` → CloudFront distribution
3. Uses CloudFront Alias (no extra charge)

### 3. CloudFront Integration

```hcl
module "mfe_cloudfront" {
  domain_name     = "dev.btg.puntedge.com"
  certificate_arn = module.acm_certificate.certificate_arn
}
```

**Actions:**
1. Adds custom domain to CloudFront distribution
2. Attaches ACM certificate for HTTPS
3. Enables SNI (Server Name Indication)

## Troubleshooting

### Issue: Certificate validation stuck

**Solution:** Check DNS propagation

```powershell
# Check if validation CNAME records exist
nslookup -type=CNAME _xxx.dev.btg.puntedge.com

# Wait 5-10 minutes and check again
terraform apply
```

### Issue: CloudFront domain not resolving

**Solution:** Wait for CloudFront propagation (10-15 minutes)

```powershell
# Check CloudFront distribution status
aws cloudfront get-distribution --id <distribution-id>

# Status should be "Deployed"
```

### Issue: SSL certificate error

**Solution:** Verify certificate is attached to CloudFront

```powershell
# Check CloudFront configuration
aws cloudfront get-distribution-config --id <distribution-id> | Select-String "Certificate"
```

## Cost Impact

| Resource | Monthly Cost |
|----------|-------------|
| **Route 53 Hosted Zone** | $0.50/month (already created) |
| **Route 53 DNS Queries** | $0.40 per million queries (~$0.01/month dev) |
| **ACM Certificate** | **FREE** ✅ |
| **CloudFront Custom Domain** | **FREE** (included in CloudFront pricing) |

**Total Additional Cost:** ~$0.50/month (negligible)

## Next Steps

1. **Dev Environment:**
   - Keep `enable_custom_domain = false` initially
   - Test with CloudFront URL first
   - Enable custom domain when ready

2. **Staging Environment:**
   - Enable custom domain: `staging.btg.puntedge.com`
   - Use for UAT and integration testing

3. **Production Environment:**
   - Enable custom domain: `btg.puntedge.com`
   - Required for production launch

## Important Notes

- **Certificate Validation:** Takes 5-30 minutes (DNS propagation)
- **CloudFront Propagation:** Takes 10-15 minutes after certificate attached
- **Domain Registration:** Currently "In Progress" (24-72 hours) - **doesn't block DNS setup**
- **Hosted Zone Ready:** Can configure DNS immediately
- **ACM Certificates:** Must be in `us-east-1` for CloudFront

## Commands Reference

```powershell
# Check hosted zone
aws route53 list-hosted-zones | Select-String "puntedge"

# Check certificate status
aws acm list-certificates --region us-east-1

# Check DNS records
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Test custom domain
Invoke-WebRequest -Uri "https://dev.btg.puntedge.com"

# Get Terraform outputs
terraform output
```
