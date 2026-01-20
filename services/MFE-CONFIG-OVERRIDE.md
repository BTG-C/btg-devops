# MFE Configuration Override Guide

## Problem

The **shell-mfe** (host application) has a `config.json` file baked into the Docker image at build time:

```
btg-shell-mfe/
  public/
    config/
      config.json  ← Built into Docker image with localhost URLs
```

**Issue:** Same Docker image needs different config per environment (dev/staging/prod)

---

## Solution: Runtime Config Override

### **Approach: S3 + CloudFront with Config Override**

The MFE deployment workflow will:
1. Build Docker image with default config (localhost)
2. Push image to GHCR
3. Upload environment-specific config to S3
4. Configure CloudFront/ALB to serve S3 config instead of Docker image config

---

## Directory Structure

```
btg-devops/services/
└── shell-mfe/
    ├── config/
    │   ├── dev.json       ← Deployment uploads this to S3
    │   ├── staging.json
    │   └── prod.json
    └── ecs/
        └── deployment-notes.md
```

**Note:** Other MFEs (enhancer-mfe) don't need runtime config - they're loaded as remote modules by shell-mfe and inherit its configuration context.

---

## Config Files

### **shell-mfe/config/dev.json**
```json
{
  "backendBaseUrl": "https://gateway-dev.yourdomain.com",
  "environment": "dev",
### **shell-mfe/config/dev.json**
```json
{
  "backendBaseUrl": "https://gateway-dev.yourdomain.com",
  "environment": "dev",
  "mfes": {
    "enhancer": "https://enhancer-mfe-dev.yourdomain.com/remoteEntry.json"
  }
}
```

### **shell-mfe/config/prod.json**
```json
{
  "backendBaseUrl": "https://gateway.yourdomain.com",
  "environment": "production",
  "mfes": {
    "enhancer": "https://enhancer-mfe.yourdomain.com/remoteEntry.json"
  }
}
```

**Why only shell-mfe needs config:**
- Shell-mfe is the **host application** - it loads config and provides it to remote MFEs
- Enhancer-mfe is a **remote module** - it receives context from shell-mfe via shared services
- Only the host needs to know backend URLs and remote entry points
### **Step 1: App Repo Builds Image**

```yaml
# In btg-shell-mfe/.github/workflows/artifact-pipeline.yml
- name: Build Docker image
  run: |
    docker build -t ghcr.io/btg-c/btg-shell-mfe:${{ github.sha }} .
    docker push ghcr.io/btg-c/btg-shell-mfe:${{ github.sha }}

- name: Trigger S3 deployment
  run: |
    curl -X POST \
      https://api.github.com/repos/BTG-C/btg-devops/dispatches \
      -d '{
        "event_type": "deploy-shell-mfe",
        "client_payload": {
          "environment": "dev",
          "image_tag": "${{ github.sha }}"
        }
      }'
```

### **Step 2: DevOps Repo Deploys to S3**

```yaml
# In btg-devops/.github/workflows/mfe-promotion-pipeline.yml
on:
  repository_dispatch:
    types: [deploy-shell-mfe]

jobs:
  deploy:
    steps:
      - name: Upload config to S3
        run: |
          ENV="${{ github.event.client_payload.environment }}"
          
          # Upload environment-specific config
          aws s3 cp \
            services/shell-mfe/config/$ENV.json \
            s3://btg-$ENV-mfe-assets/config/config.json \
            --content-type application/json \
            --cache-control "no-cache, no-store, must-revalidate"
      
      - name: Upload static assets to S3
        run: |
          # Extract static files from Docker image
          docker run --rm \
            -v $(pwd)/dist:/output \
            ghcr.io/btg-c/btg-shell-mfe:${{ github.event.client_payload.image_tag }} \
            sh -c "cp -r /usr/share/nginx/html/* /output/"
          
          # Upload to S3 (excluding config - we uploaded custom one above)
          aws s3 sync dist/ s3://btg-$ENV-mfe-assets/ \
            --exclude "config/config.json" \
            --cache-control "public, max-age=31536000, immutable"
      
      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/config/config.json" "/*"
```

---

## Infrastructure Setup (Terraform)

### **S3 Bucket for MFE Assets**

```hcl
# infrastructure/terraform/modules/mfe-cloudfront/main.tf
# CloudFront serves config files with no caching

resource "aws_s3_bucket" "mfe_assets" {
  bucket = "btg-${var.environment}-mfe-assets"
}

resource "aws_s3_bucket_public_access_block" "mfe_assets" {
  bucket = aws_s3_bucket.mfe_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "mfe_assets" {
  bucket = aws_s3_bucket.mfe_assets.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"  # SPA routing
  }
}
```

### **CloudFront Distribution**

```hcl
resource "aws_cloudfront_distribution" "shell_mfe" {
  enabled = true
  aliases = ["app-${var.environment}.yourdomain.com"]

  origin {
    domain_name = aws_s3_bucket.mfe_assets.bucket_regional_domain_name
    origin_id   = "S3-shell-mfe"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.mfe.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id = "S3-shell-mfe"
    
    # config.json should never be cached
    cached_methods = ["GET", "HEAD"]
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Special cache behavior for config.json (no cache)
  ordered_cache_behavior {
    path_pattern     = "/config/config.json"
    target_origin_id = "S3-shell-mfe"
    
    cached_methods = ["GET", "HEAD"]
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0    # ← No cache
    max_ttl                = 0    # ← No cache
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
  }
}
```

---

## How It Works

### **Build Time** (in app repo)
```
Docker build → public/config/config.json (localhost URLs) → ghcr.io/btg-c/shell-mfe:v1.2.3
```

### **Deployment Time** (in devops repo)
```
1. Upload btg-devops/services/shell-mfe/config/dev.json → S3
2. Extract static assets from Docker image → S3
3. CloudFront serves S3 version of config.json (overrides Docker version)
```

### **Runtime** (in browser)
```
Browser → https://app-dev.yourdomain.com/config/config.json
         ↓
      CloudFront (no cache for config.json)
         ↓
      S3 (environment-specific config)
         ↓
      Browser gets dev config ✅
```

---

## Config Loading in Angular

### **Existing Code (in shell-mfe)**

```typescript
// src/lib/services/config-info.store.ts
export const ConfigInfoStore = signalStore(
  { providedIn: 'root' },
  withState<ConfigState>({
    config: null,
    isInitialized: false
  }),
  withMethods((store) => {
    const CONFIG_URL = '/config/config.json';  // ← Loads from CloudFront/S3
    
    const fetchConfig = (): Observable<ConfigInfo> => {
      return http.get<ConfigInfo>(CONFIG_URL).pipe(
        catchError((error) => {
          console.error('Failed to load config:', error);
          return throwError(() => new Error(`Failed to load config`));
        })
      );
    };
    
    return {
      ensureConfigLoaded: async (): Promise<ConfigInfo> => {
        if (store.isInitialized()) {
          return store.config()!;
        }
        
        const config = await firstValueFrom(fetchConfig());
        patchState(store, { config, isInitialized: true });
        return config;
      }
    };
  })
);
```

**No code changes needed!** The MFE always requests `/config/config.json`, which CloudFront serves from S3 with environment-specific values.

---

## Advantages

### **✅ Same Docker Image Everywhere**
- Build once in app repo
- Deploy to dev, staging, prod with different configs
- Immutable images (best practice)

### **✅ No Rebuilds for Config Changes**
- Update config in `btg-devops/services/shell-mfe/config/prod.json`
- Run deployment workflow
- New config live in minutes

### **✅ Separation of Concerns**
- App repo: Builds application code
- DevOps repo: Manages environment configs
- No secrets in app repo

### **✅ Fast Deployments**
- No Docker rebuild
- Just S3 upload + CloudFront invalidation
- < 1 minute to update config

---

## Deployment Commands

### **Deploy New Version**
```bash
# Trigger from app repo (after Docker build)
gh workflow run artifact-pipeline.yml
```

### **Update Config Only**
```bash
# Edit config
vim btg-devops/services/shell-mfe/config/prod.json

# Upload to S3
aws s3 cp services/shell-mfe/config/prod.json \
  s3://btg-prod-mfe-assets/config/config.json \
  --content-type application/json \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/config/config.json"
```

---

## Verification

### **Check Config in Browser**
```bash
# Dev
curl https://app-dev.yourdomain.com/config/config.json

# Should return:
{
  "backendBaseUrl": "https://gateway-dev.yourdomain.com",
  "environment": "dev",
  ...
}
```

### **Check S3**
```bash
aws s3 cp s3://btg-dev-mfe-assets/config/config.json -
```

### **Check CloudFront Cache**
```bash
# Should show cache headers indicating no-cache
curl -I https://app-dev.yourdomain.com/config/config.json

# Cache-Control: no-cache, no-store, must-revalidate
```
**For Shell-MFE (Angular Host App):**
- ✅ Config stored in `btg-devops/services/shell-mfe/config/{env}.json`
- ✅ Deployment uploads config to S3
- ✅ CloudFront serves S3 version (overrides Docker image version)
- ✅ Browser loads environment-specific config at runtime
- ✅ Config shared with remote MFEs via Angular services
**For MFEs (Angular):**
- ✅ Config stored in `btg-devops/services/{mfe-name}/config/{env}.json`
- ✅ Deployment uploads config to S3
- ✅ CloudFront serves S3 version (overrides Docker image version)
- ✅ Browser loads environment-specific config at runtime

**For Java Services:**
- ✅ Config stored in `btg-devops/services/{service-name}/config/{env}.json`
- ✅ Deployment creates task definition with environment variables
- ✅ ECS injects config as environment variables at container startup
- ✅ Spring Boot reads from environment variables

**Both approaches achieve the same goal: Same Docker image, different configs per environment!** 🎯
