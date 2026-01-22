# Route53 and SSL Integration - Quick Reference

## ✅ What Was Changed

### New Terraform Modules Created

1. **`modules/route53`** - DNS record management
   - Manages A records for CloudFront distributions
   - Uses existing hosted zone (puntedge.com)
   - Supports MFE and API subdomains

2. **`modules/acm-certificate`** - SSL certificate provisioning
   - Requests ACM certificates
   - Automatic DNS validation via Route 53
   - Waits for certificate validation

### Updated Environment Configurations

All three environments (dev/staging/prod) now have:

**New Variables:**
```hcl
variable "root_domain" {
  default = "puntedge.com"
}

variable "enable_custom_domain" {
  default = false  # dev
  default = true   # staging/prod
}

variable "subdomain" {
  default = "dev.btg"      # dev
  default = "staging.btg"  # staging
  default = "btg"          # prod
}
```

**Removed Variables:**
- `domain_name` (replaced by `root_domain` + `subdomain`)
- `certificate_arn` (now auto-generated via ACM module)

## 🚀 How to Use

### Option 1: Deploy WITHOUT Custom Domain (Dev Default)

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform init
terraform plan
terraform apply
```

**Result:**
- Uses CloudFront URL: `https://d123abc.cloudfront.net`
- No DNS configuration
- No SSL certificate provisioning
- Zero additional cost

### Option 2: Deploy WITH Custom Domain

```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev

# Create terraform.tfvars
@"
enable_custom_domain = true
"@ | Out-File -FilePath terraform.tfvars

terraform init
terraform plan   # Review: Should show ACM cert + Route53 records
terraform apply  # Takes 5-30 mins for cert validation
```

**Result:**
- URL: `https://dev.btg.puntedge.com`
- ACM certificate auto-provisioned
- DNS A record auto-configured
- ~$0.50/month additional cost

## 📋 Environment URLs

| Environment | URL | Status |
|-------------|-----|--------|
| **Dev** | `https://dev.btg.puntedge.com` | Optional (disabled by default) |
| **Staging** | `https://staging.btg.puntedge.com` | Enabled by default |
| **Production** | `https://btg.puntedge.com` | Enabled by default |

## ⚙️ Configuration Summary

### Development (env-dev)
```hcl
enable_custom_domain = false  # Use CloudFront URL
subdomain            = "dev.btg"
root_domain          = "puntedge.com"
```

### Staging (env-staging)
```hcl
enable_custom_domain = true   # Use custom domain
subdomain            = "staging.btg"
root_domain          = "puntedge.com"
```

### Production (env-prod)
```hcl
enable_custom_domain = true   # REQUIRED for production
subdomain            = "btg"
root_domain          = "puntedge.com"
```

## 🔍 Verification Commands

```powershell
# Check Terraform outputs
terraform output custom_domain_url
terraform output certificate_arn
terraform output dns_name_servers

# Check DNS resolution
nslookup dev.btg.puntedge.com

# Check HTTPS
Invoke-WebRequest -Uri "https://dev.btg.puntedge.com"

# Check ACM certificate
aws acm list-certificates --region us-east-1 | Select-String "dev.btg.puntedge.com"

# Check Route53 records
aws route53 list-resource-record-sets --hosted-zone-id <zone-id> | Select-String "dev.btg"
```

## 📊 Resource Summary

### Per Environment (when enabled)

| Resource | Type | Cost | Notes |
|----------|------|------|-------|
| ACM Certificate | `aws_acm_certificate` | FREE ✅ | Auto-renews |
| DNS Validation Records | `aws_route53_record` (CNAME) | FREE | 3 records |
| A Record | `aws_route53_record` | $0.01/month | CloudFront alias |
| Hosted Zone | `aws_route53_zone` | $0.50/month | Shared across all envs |

**Total Additional Cost per Environment:** ~$0.01/month  
**Total for all 3 Environments:** ~$0.50/month (hosted zone shared)

## 🎯 Next Steps

1. **Test Dev Environment:**
   ```powershell
   cd env-dev
   terraform init
   terraform apply  # Without custom domain
   ```

2. **Enable Custom Domain (Optional):**
   ```powershell
   # Add to terraform.tfvars
   enable_custom_domain = true
   
   terraform apply
   ```

3. **Deploy Staging/Production:**
   ```powershell
   cd env-staging
   terraform init
   terraform apply  # Custom domain enabled by default
   ```

## ⚠️ Important Notes

1. **Domain Registration:** Currently "In Progress" (24-72 hours)
   - Does NOT block DNS/SSL setup ✅
   - Hosted zone is already available

2. **Certificate Validation:** Takes 5-30 minutes
   - Automatic via DNS validation
   - No manual intervention needed

3. **CloudFront Propagation:** Takes 10-15 minutes
   - Distribution updates after cert attachment
   - Normal CloudFront behavior

4. **Module Dependencies:**
   ```
   route53 → Requires: hosted zone (already exists)
   acm_certificate → Requires: hosted zone ID
   mfe_cloudfront → Requires: certificate ARN
   ```

## 🆘 Troubleshooting

See detailed troubleshooting guide in:
- `docs/infrastructure/DNS-SSL-SETUP.md`

Common issues:
- Certificate validation stuck → Wait 10 mins, check DNS propagation
- CloudFront not resolving → Wait 15 mins for distribution update
- SSL error → Verify certificate attached to CloudFront
