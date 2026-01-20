# Pre-Deployment Checklist

**Quick validation before deploying to production**

---

## ✅ Configuration Files

### All Services Have Config Files
- `services/gateway-service/config/{dev,staging,prod}.json`
- `services/auth-server/config/{dev,staging,prod}.json`
- `services/enhancer-service/config/{dev,staging,prod}.json`
- `services/score-odd-service/config/{dev,staging,prod}.json`
- `services/shell-mfe/config/{dev,staging,prod}.json`

### Config Structure
```json
{
  "envVars": {
    "SERVICE_URL": "https://...",
    "LOG_LEVEL": "INFO"
  },
  "secrets": {
    "SECRET_NAME": "btg/{env}/secret-path"
  }
}
```

---

## ✅ Task Definition Templates

### All Services Have Templates
- `services/gateway-service/ecs/task-definition-template.json`
- `services/auth-server/ecs/task-definition-template.json`
- `services/enhancer-service/ecs/task-definition-template.json`
- `services/score-odd-service/ecs/task-definition-template.json`

### Naming Verified
| Service | Family | Container | Port |
|---------|--------|-----------|------|
| Gateway | `btg-{{ENVIRONMENT}}-gateway-service` | `gateway-service` | 8080 |
| Auth | `btg-{{ENVIRONMENT}}-auth-server` | `auth-server` | 9000 |
| Enhancer | `btg-{{ENVIRONMENT}}-enhancer-service` | `enhancer-service` | 8081 |
| Score-Odd | `btg-{{ENVIRONMENT}}-score-odd-service` | `score-odd-service` | 8082 |

---

## ✅ Workflows

### All Deployment Workflows Exist
- `.github/workflows/gateway-service-deployment.yml`
- `.github/workflows/auth-server-deployment.yml`
- `.github/workflows/enhancer-service-deployment.yml`
- `.github/workflows/score-odd-service-deployment.yml`
- `.github/workflows/mfe-promotion-pipeline.yml`

### Workflow Pattern
1. Load config from `services/{service}/config/{env}.json`
2. Prepare task definition from template
3. Inject environment variables from config
4. Replace placeholders ({{ENVIRONMENT}}, {{IMAGE_TAG}}, etc.)
5. Register task definition with ECS
6. Update ECS service
7. Wait for stability

---

## ✅ Secrets in AWS Secrets Manager

### Gateway Service
- `btg/{env}/mongodb-uri`
- `btg/{env}/gateway-client-secret`

### Auth Server
- `btg/{env}/mongodb-auth-uri`

### Enhancer Service
- `btg/{env}/mongodb-uri`
- `btg/{env}/score-odd-api-key`

### Score-Odd Service
- `btg/{env}/mongodb-uri`
- `btg/{env}/score-odd-api-key`

---

## ✅ Environment URLs

| Environment | Gateway API | Shell MFE |
|-------------|-------------|-----------|
| Dev | `https://api-dev.btgcric.com` | `https://dev.btgcric.com` |
| Staging | `https://api-staging.btgcric.com` | `https://staging.btgcric.com` |
| Production | `https://api.btgcric.com` | `https://btgcric.com` |

---

## 🔧 Pre-Deployment Setup

### 1. Terraform Infrastructure
```bash
cd infrastructure/terraform/env-dev
terraform init
terraform plan
terraform apply
```

**Creates:**
- ECS Cluster: `btg-dev-cluster`
- ALBs: Public gateway, internal auth, internal backend
- S3 Bucket: `btg-dev-mfe-assets`
- CloudFront Distribution
- IAM Roles: Execution and task roles
- CloudWatch Log Groups

### 2. Populate Secrets
```bash
# MongoDB URIs
aws secretsmanager create-secret \
  --name btg/dev/mongodb-uri \
  --secret-string "mongodb://..."

aws secretsmanager create-secret \
  --name btg/dev/mongodb-auth-uri \
  --secret-string "mongodb://..."

# OAuth2 client secret
aws secretsmanager create-secret \
  --name btg/dev/gateway-client-secret \
  --secret-string "your-client-secret"

# API keys
aws secretsmanager create-secret \
  --name btg/dev/score-odd-api-key \
  --secret-string "your-api-key"
```

### 3. Configure GitHub
```bash
# Create environments: dev, staging, prod
# Add secrets per environment:
- AWS_ROLE_ARN
- AWS_REGION
- AWS_ACCOUNT_ID
- GATEWAY_ALB_URL (for smoke tests)
```

### 4. DNS Configuration
```bash
# Point domains to load balancers
api-dev.btgcric.com → Gateway ALB
dev.btgcric.com → CloudFront Distribution
```

---

## 🚀 Deployment Process

### Step 1: Build in App Repo
```yaml
# btg-gateway-service/.github/workflows/artifact-pipeline.yml
- Build Docker image
- Push to ghcr.io/btg-c/btg-gateway-service:sha-abc123
- Dispatch event to btg-devops repo
```

### Step 2: Deploy from DevOps Repo
```yaml
# btg-devops/.github/workflows/gateway-service-deployment.yml
- Load services/gateway-service/config/dev.json
- Prepare task definition from template
- Deploy to ECS
```

### Step 3: Verify
```bash
# Check service status
aws ecs describe-services \
  --cluster btg-dev-cluster \
  --services btg-dev-gateway-service

# Check logs
aws logs tail /ecs/btg-dev-gateway-service --follow
```

---

## 🔍 Quick Validation

### Test Config File Syntax
```bash
jq . services/gateway-service/config/dev.json
```

### Test Task Definition
```bash
# Prepare task definition locally
CONFIG_FILE="services/gateway-service/config/dev.json"
cp services/gateway-service/ecs/task-definition-template.json task-def.json
sed -i "s/{{ENVIRONMENT}}/dev/g" task-def.json
sed -i "s/{{IMAGE_TAG}}/test/g" task-def.json
sed -i "s/{{AWS_ACCOUNT_ID}}/123456789012/g" task-def.json
sed -i "s/{{AWS_REGION}}/us-east-1/g" task-def.json

# Validate JSON
jq . task-def.json
```

### Verify Secret Exists
```bash
aws secretsmanager get-secret-value \
  --secret-id btg/dev/mongodb-uri
```

---

## 📚 Related Documentation

- **Configuration Flow**: `docs/development/CONFIGURATION-FLOW.md`
- **Service Naming**: `services/SERVICE-NAMING-CONVENTION.md`
- **MFE Config Override**: `services/MFE-CONFIG-OVERRIDE.md`
- **GitHub Environments**: `docs/development/GITHUB-ENVIRONMENTS-SETUP.md`

---

## ✅ Deployment Ready

When all checkboxes above are complete, system is ready for deployment.

