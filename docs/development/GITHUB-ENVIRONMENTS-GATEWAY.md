# GitHub Environment Secrets Configuration
# Configure these in: GitHub → Settings → Environments

## Dev Environment

**Environment name:** `dev`

**Protection rules:**
- ❌ No required reviewers
- ❌ No wait timer
- ✅ Restrict to `develop` branch only

**Secrets:**

```yaml
# AWS Configuration
AWS_ACCOUNT_ID: "123456789012"           # Dev AWS account ID
AWS_REGION: "us-east-1"                  # AWS region
AWS_ROLE_ARN: "arn:aws:iam::123456789012:role/github-actions-dev"

# Gateway Service Configuration
GATEWAY_CLUSTER: "btg-dev-cluster"       # ECS cluster name
GATEWAY_SERVICE: "btg-gateway-service"   # ECS service name
GATEWAY_ALB_URL: "https://api-dev.btg.com"  # ALB URL for smoke tests

# Shell MFE Configuration
SHELL_S3_BUCKET: "btg-dev-shell-blue"
SHELL_CLOUDFRONT_ID: "E1234567890ABC"
SHELL_CLOUDFRONT_URL: "https://dev-shell.btg.com"

# Enhancer MFE Configuration
ENHANCER_S3_BUCKET: "btg-dev-enhancer-blue"
ENHANCER_CLOUDFRONT_ID: "E0987654321XYZ"
ENHANCER_CLOUDFRONT_URL: "https://dev-enhancer.btg.com"
```

---

## Production Environment

**Environment name:** `production`

**Protection rules:**
- ✅ Required reviewers: 2 (@devops-lead, @engineering-manager)
- ✅ Wait timer: 5 minutes
- ✅ Restrict to `main` branch only

**Secrets:**

```yaml
# AWS Configuration
AWS_ACCOUNT_ID: "987654321098"           # Prod AWS account ID
AWS_REGION: "us-east-1"                  # AWS region
AWS_ROLE_ARN: "arn:aws:iam::987654321098:role/github-actions-prod"

# Gateway Service Configuration
GATEWAY_CLUSTER: "btg-prod-cluster"      # ECS cluster name
GATEWAY_SERVICE: "btg-gateway-service"   # ECS service name
GATEWAY_ALB_URL: "https://api.btg.com"   # ALB URL for smoke tests

# Shell MFE Configuration
SHELL_S3_BUCKET: "btg-prod-shell-blue"
SHELL_CLOUDFRONT_ID: "EPRODABC123456"
SHELL_CLOUDFRONT_URL: "https://shell.btg.com"

# Enhancer MFE Configuration
ENHANCER_S3_BUCKET: "btg-prod-enhancer-blue"
ENHANCER_CLOUDFRONT_ID: "EPRODXYZ987654"
ENHANCER_CLOUDFRONT_URL: "https://enhancer.btg.com"
```

---

## Task Definition Placeholder Mapping

**Template placeholders → GitHub secrets:**

| Placeholder | GitHub Secret | Example Value |
|------------|---------------|---------------|
| `{{IMAGE_TAG}}` | `github.event.client_payload.image_tag` | `v1.2.3` |
| `{{ENVIRONMENT}}` | Environment name | `dev` or `production` |
| `{{AWS_REGION}}` | `AWS_REGION` | `us-east-1` |
| `{{AWS_ACCOUNT_ID}}` | `AWS_ACCOUNT_ID` | `123456789012` |

**Workflow does the replacement:**
```bash
sed -i "s|{{IMAGE_TAG}}|v1.2.3|g" task-definition.json
sed -i "s|{{ENVIRONMENT}}|production|g" task-definition.json
sed -i "s|{{AWS_REGION}}|us-east-1|g" task-definition.json
sed -i "s|{{AWS_ACCOUNT_ID}}|987654321098|g" task-definition.json
```

**Result:** Task definition ready for ECS registration
