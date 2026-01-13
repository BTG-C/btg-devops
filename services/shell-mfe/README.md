# Shell MFE Deployment Configuration

**S3 + CloudFront deployment configuration for btg-shell-mfe (Angular Shell)**

---

## Service Overview

- **Type:** Frontend micro-frontend (Angular Shell)
- **Hosting:** S3 + CloudFront
- **Path:** `/` (root)
- **Repository:** [btg-shell-mfe](https://github.com/BTG-C/btg-shell-mfe)

---

## Directory Structure

```
services/shell-mfe/
├── README.md                    # This file
├── s3/
│   ├── deploy-config.yaml       # S3 bucket configuration
│   └── cache-headers.yaml       # Cache-Control headers per file type
└── cloudfront/
    ├── distribution-config.yaml # CloudFront settings
    └── invalidation-paths.txt   # Paths to invalidate on deployment
```

---

## GitHub Environment Variables

### Development (`dev`)

**Location:** GitHub → Settings → Environments → dev → Variables

```yaml
# AWS Configuration
AWS_ROLE_ARN: arn:aws:iam::123456789012:role/github-actions-dev
AWS_REGION: us-east-1
S3_BUCKET: btg-dev-blue
CLOUDFRONT_DISTRIBUTION_ID: E1234567890ABC

# Runtime Configuration (Injected at deployment)
RUNTIME_CONFIG: |
  {
    "apiEndpoint": "https://api-dev.btg.com",
    "oauthClientId": "client-id-dev",
    "environment": "dev",
    "features": {
      "analytics": false,
      "debugMode": true
    },
    "mfes": {
      "shell": "/",
      "enhancer": "/mfe-bundles/enhancer/remoteEntry.json"
    }
  }
```

### Staging (`staging`)

Same structure, with staging-specific values.

### Production (`production`)

Same structure, with production-specific values.

**Production Runtime Config Example:**
```json
{
  "apiEndpoint": "https://api.btg.com",
  "oauthClientId": "client-id-prod",
  "environment": "production",
  "features": {
    "analytics": true,
    "debugMode": false
  },
  "mfes": {
    "shell": "/",
    "enhancer": "/mfe-bundles/enhancer/remoteEntry.json"
  }
}
```

---

## S3 Deployment Structure

```
s3://btg-prod-blue/
├── index.html                   # Cache-Control: no-cache
├── config/
│   └── config.json             # Cache-Control: no-cache (injected at deploy)
├── main.abc123.js              # Cache-Control: max-age=31536000, immutable
├── polyfills.def456.js         # Cache-Control: max-age=31536000, immutable
├── styles.ghi789.css           # Cache-Control: max-age=31536000, immutable
├── runtime.jkl012.js           # Cache-Control: max-age=31536000, immutable
└── assets/
    └── shell/
        ├── logo.png            # Cache-Control: max-age=31536000, immutable
        └── favicon.ico         # Cache-Control: max-age=31536000, immutable
```

---

## Cache Strategy

### Cache Headers Configuration

**File:** `s3/cache-headers.yaml`

```yaml
# No-cache files (always check server for updates)
no_cache:
  - "*.html"
  - "config/*.json"
  - "remoteEntry.json"
  cache_control: "no-cache, no-store, must-revalidate"
  expires: "0"

# Immutable files (hash in filename, never changes)
immutable:
  - "*.js"
  - "*.css"
  - "*.woff2"
  - "*.png"
  - "*.jpg"
  - "*.svg"
  cache_control: "public, max-age=31536000, immutable"
```

### CloudFront Invalidation

**File:** `cloudfront/invalidation-paths.txt`

```
/index.html
/config/*
/*.html
```

**Why selective invalidation?**
- Hashed files (main.abc123.js) don't need invalidation (filename changes = cache miss)
- Only invalidate HTML and config files that users must get fresh

---

## Deployment Process

### Automatic Deployment

**Trigger:** Push to `develop` or `release/*` branch in `btg-shell-mfe` repo

1. App repo builds production bundle: `ng build --configuration=production`
2. App repo creates tarball: `btg-shell-mfe-develop-abc123-20260113143052.tar.gz`
3. App repo uploads to GitHub Artifacts
4. App repo triggers DevOps repo via `repository_dispatch`
5. DevOps repo downloads artifact
6. DevOps repo deploys to S3 with cache headers
7. DevOps repo injects runtime `config.json` (environment-specific)
8. DevOps repo invalidates CloudFront cache

**Timeline:** 3-5 minutes

### Manual Deployment

```powershell
cd c:\Git\btg-devops
gh workflow run promotion-pipeline.yml \
  -f service=shell-mfe \
  -f image_tag=release-v1.2.0-abc123-20260113143052 \
  -f environment=production
```

---

## Runtime Configuration

### How It Works

1. **Build time:** Angular app is built WITHOUT environment-specific values
2. **Deploy time:** DevOps workflow injects `config/config.json` with GitHub Environment variables
3. **Runtime:** Angular app fetches `/config/config.json` before bootstrap

### Implementation (main.ts)

```typescript
// main.ts
fetch('/config/config.json')
  .then(res => res.json())
  .then(config => {
    platformBrowserDynamic([
      { provide: APP_CONFIG, useValue: config }
    ]).bootstrapModule(AppModule);
  })
  .catch(err => {
    console.error('Failed to load config:', err);
    // Fallback to defaults
    platformBrowserDynamic([
      { provide: APP_CONFIG, useValue: DEFAULT_CONFIG }
    ]).bootstrapModule(AppModule);
  });
```

### Config Interface (app.config.ts)

```typescript
export interface AppConfig {
  apiEndpoint: string;
  oauthClientId: string;
  environment: 'dev' | 'staging' | 'production';
  features: {
    analytics: boolean;
    debugMode: boolean;
  };
  mfes: {
    shell: string;
    enhancer: string;
  };
}

export const APP_CONFIG = new InjectionToken<AppConfig>('APP_CONFIG');
```

---

## Monitoring

### CloudFront Metrics

**Dashboard:** [CloudFront Monitoring](https://console.aws.amazon.com/cloudfront/v3/home#/monitoring)

**Key Metrics:**
- **Requests:** Total page views
- **Error Rate:** 4xx + 5xx errors (target <1%)
- **Cache Hit Ratio:** Target >85%
- **Origin Latency:** S3 response time (target <100ms)

### Real User Monitoring (RUM)

```typescript
// Integrate with CloudWatch RUM or Datadog
import { datadogRum } from '@datadog/browser-rum';

datadogRum.init({
  applicationId: '<app-id>',
  clientToken: '<client-token>',
  site: 'datadoghq.com',
  service: 'shell-mfe',
  env: config.environment,
  version: '1.2.0',
  sampleRate: 100,
  trackInteractions: true,
});
```

### Web Vitals

Monitor via CloudWatch RUM:
- **LCP (Largest Contentful Paint):** Target <2.5s
- **FID (First Input Delay):** Target <100ms
- **CLS (Cumulative Layout Shift):** Target <0.1

---

## Troubleshooting

### Users See Old Version After Deployment

**Cause:** CloudFront cache not invalidated or users have browser cache

**Solution:**
```powershell
# Force CloudFront invalidation
aws cloudfront create-invalidation \
  --distribution-id EABCDEF123456 \
  --paths "/*"

# Check invalidation status
aws cloudfront list-invalidations \
  --distribution-id EABCDEF123456 \
  --max-items 1
```

**Prevention:** Ensure `index.html` has `Cache-Control: no-cache`

### Config.json Returns 404

**Cause:** Config file not deployed or wrong S3 path

**Solution:**
```powershell
# Check if config exists in S3
aws s3 ls s3://btg-prod-blue/config/config.json

# If missing, re-run deployment
gh workflow run promotion-pipeline.yml \
  -f service=shell-mfe \
  -f image_tag=<current-version> \
  -f environment=production
```

### Module Federation Remote Entry Fails to Load

**Cause:** MFE not deployed or incorrect path in config.json

**Solution:**
```powershell
# Verify enhancer MFE is deployed
aws s3 ls s3://btg-prod-blue/mfe-bundles/enhancer/remoteEntry.json

# Test remote entry URL
curl https://btg.com/mfe-bundles/enhancer/remoteEntry.json

# Check config.json has correct path
curl https://btg.com/config/config.json | jq '.mfes.enhancer'
```

---

## Rollback

See [Rollback Procedures](../../docs/operations/ROLLBACK-PROCEDURES.md)

**Quick rollback:**
```powershell
gh workflow run rollback-pipeline.yml \
  -f service=shell-mfe \
  -f image_tag=<previous-stable-version> \
  -f environment=production
```

**Note:** Artifacts retained for 90 days in GitHub Artifacts. Cannot rollback beyond that.

---

## Performance Optimization

### Bundle Size Targets

| Bundle | Target | Current |
|--------|--------|---------|
| **main.js** | <300KB | 245KB |
| **polyfills.js** | <100KB | 87KB |
| **styles.css** | <50KB | 32KB |
| **Total (gzipped)** | <500KB | 412KB |

### Optimization Checklist

- [ ] **Tree shaking:** Remove unused code
- [ ] **Lazy loading:** Load routes on demand
- [ ] **Image optimization:** Use WebP format
- [ ] **Font subsetting:** Only include used characters
- [ ] **Code splitting:** Split vendor bundles
- [ ] **Minification:** Enabled in production build
- [ ] **Compression:** Brotli + gzip enabled on CloudFront

---

## Related Resources

- [App Repository](https://github.com/BTG-C/btg-shell-mfe)
- [Module Federation Guide](https://github.com/BTG-C/btg-shell-mfe/blob/main/docs/MODULE-FEDERATION.md)
- [Deployment Runbook](../../docs/operations/DEPLOYMENT-RUNBOOK.md)
- [Architecture Overview](../../docs/architecture/OVERVIEW.md)

---

**Last Updated:** 2026-01-13  
**Service Owner:** Frontend Team  
**On-Call:** #frontend-oncall
