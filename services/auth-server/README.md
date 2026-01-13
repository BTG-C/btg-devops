# Auth Server Deployment Configuration

**ECS deployment configuration for btg-auth-server service**

---

## Service Overview

- **Type:** Backend microservice (Spring Boot)
- **Container:** ECS Fargate
- **Port:** 9000
- **Health Check:** `/actuator/health`
- **Image:** `ghcr.io/btg-c/btg-auth-server:{tag}`

---

## Directory Structure

```
services/auth-server/
├── README.md                    # This file
├── ecs/
│   ├── service-blueprint.json   # ECS task definition template with placeholders
│   ├── task-dev.json            # Dev-specific overrides (optional)
│   ├── task-staging.json        # Staging-specific overrides (optional)
│   └── task-prod.json           # Production-specific overrides (optional)
└── config/
    ├── github-env-dev.yaml      # Dev GitHub Environment variables
    ├── github-env-staging.yaml  # Staging GitHub Environment variables
    └── github-env-prod.yaml     # Production GitHub Environment variables
```

---

## GitHub Environment Variables

### Development (`dev`)

**Location:** GitHub → Settings → Environments → dev → Variables

```yaml
# AWS Configuration
AWS_ROLE_ARN: arn:aws:iam::123456789012:role/github-actions-dev
AWS_REGION: us-east-1
ECS_CLUSTER: btg-dev-cluster
ECS_SERVICE: auth-server

# Secret ARNs (from AWS Secrets Manager)
MONGODB_URI_SECRET_ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/dev/mongodb-uri
ADMIN_PASSWORD_SECRET_ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/dev/admin-password
GATEWAY_CLIENT_SECRET_ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/dev/gateway-client-secret
MICROSERVICES_CLIENT_SECRET_ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/dev/microservices-client-secret
GHCR_PAT_SECRET_ARN: arn:aws:secretsmanager:us-east-1:123456789012:secret:github/packages-pat

# Application Configuration
LOG_LEVEL_ROOT: INFO
LOG_LEVEL_APP: DEBUG
SPRING_PROFILES_ACTIVE: dev
SERVER_PORT: 9000

# Service Health
SERVICE_HEALTH_URL: https://api-dev.btg.com/actuator/health
```

### Staging (`staging`)

Same structure as dev, with staging-specific ARNs and values.

### Production (`production`)

Same structure as dev, with production-specific ARNs and values.

**Additional Protection Rules:**
- Required reviewers: 2 (DevOps Lead + Release Manager)
- Wait timer: 5 minutes
- Deployment branches: `main` only

---

## ECS Task Definition Blueprint

**File:** `ecs/service-blueprint.json`

This template uses placeholders (`${VARIABLE}`) that get replaced at deployment time with values from GitHub Environments.

**Key Sections:**

### Container Definition
```json
{
  "name": "auth-server",
  "image": "ghcr.io/btg-c/btg-auth-server:${IMAGE_TAG}",
  "repositoryCredentials": {
    "credentialsParameter": "${GHCR_PAT_SECRET_ARN}"
  }
}
```

### Secrets (from AWS Secrets Manager)
```json
"secrets": [
  {
    "name": "MONGODB_URI",
    "valueFrom": "${MONGODB_URI_SECRET_ARN}"
  },
  {
    "name": "ADMIN_PASSWORD",
    "valueFrom": "${ADMIN_PASSWORD_SECRET_ARN}"
  }
]
```

### Environment Variables (Non-Secret)
```json
"environment": [
  {
    "name": "SPRING_PROFILES_ACTIVE",
    "value": "${SPRING_PROFILES_ACTIVE}"
  },
  {
    "name": "LOG_LEVEL_ROOT",
    "value": "${LOG_LEVEL_ROOT}"
  }
]
```

---

## Deployment Process

### Automatic Deployment

**Trigger:** Push to `develop` or `release/*` branch in `btg-auth-server` repo

1. App repo builds Docker image: `ghcr.io/btg-c/btg-auth-server:develop-abc123`
2. App repo triggers DevOps repo via `repository_dispatch`
3. DevOps repo runs `promotion-pipeline.yml`
4. Pipeline hydrates `service-blueprint.json` with GitHub Environment values
5. Pipeline deploys to ECS

**Timeline:** 5-10 minutes

### Manual Deployment

```powershell
cd c:\Git\btg-devops
gh workflow run promotion-pipeline.yml \
  -f service=auth-server \
  -f image_tag=release-v1.2.0-abc123-20260113143052 \
  -f environment=production
```

---

## Health Checks

### ECS Health Check
```json
"healthCheck": {
  "command": ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9000/actuator/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

### Manual Health Check
```powershell
# Development
curl https://api-dev.btg.com/actuator/health

# Staging
curl https://api-staging.btg.com/actuator/health

# Production
curl https://api.btg.com/actuator/health

# Expected response:
# {"status":"UP","groups":["liveness","readiness"]}
```

---

## Monitoring

### CloudWatch Dashboards
- **Dev:** [btg-dev-auth-server](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-dev-auth-server)
- **Staging:** [btg-staging-auth-server](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-staging-auth-server)
- **Production:** [btg-prod-auth-server](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-prod-auth-server)

### Key Metrics
- **ECS Running Tasks:** Should equal desired count (2 in prod)
- **CPU Utilization:** Target <70%
- **Memory Utilization:** Target <70%
- **Response Time p95:** Target <500ms
- **Error Rate:** Target <1%

### CloudWatch Logs
```powershell
# Tail logs in real-time
aws logs tail /ecs/auth-server --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /ecs/auth-server \
  --filter-pattern "ERROR"
```

---

## Rollback

See [Rollback Procedures](../../docs/operations/ROLLBACK-PROCEDURES.md)

**Quick rollback:**
```powershell
gh workflow run rollback-pipeline.yml \
  -f service=auth-server \
  -f image_tag=<previous-stable-version> \
  -f environment=production
```

---

## Troubleshooting

### Task Fails to Start

**Check logs:**
```powershell
aws ecs describe-tasks \
  --cluster btg-prod-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].{stopCode:stopCode,stopReason:stopReason}'
```

**Common issues:**
- `CannotPullContainerError` → GHCR authentication failed (check GHCR_PAT_SECRET_ARN)
- `ResourceInitializationError` → Secrets Manager access denied (check task execution role)
- `EssentialContainerExited` → Application startup failed (check CloudWatch logs)

### Service Unhealthy

**Check health endpoint:**
```powershell
# Get task private IP
aws ecs describe-tasks \
  --cluster btg-prod-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
  --output text

# Test health check directly
curl http://<private-ip>:9000/actuator/health
```

---

## Related Resources

- [App Repository](https://github.com/BTG-C/btg-auth-server)
- [Service Documentation](https://github.com/BTG-C/btg-auth-server/blob/main/README.md)
- [Deployment Runbook](../../docs/operations/DEPLOYMENT-RUNBOOK.md)
- [Architecture Overview](../../docs/architecture/OVERVIEW.md)

---

**Last Updated:** 2026-01-13  
**Service Owner:** Backend Team  
**On-Call:** #backend-oncall
