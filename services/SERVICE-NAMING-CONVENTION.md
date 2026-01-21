# Service Naming Convention

## Overview

This document defines the naming conventions used across Terraform, GitHub Actions, and AWS resources to ensure consistency.

---

## Service Definitions

### **Gateway Service**

| Component | Name/Value | Location |
|-----------|------------|----------|
| **Source Repo** | `btg-gateway-service` | GitHub: BTG-C/btg-gateway-service |
| **Docker Image** | `ghcr.io/btg-c/btg-gateway-service` | GitHub Container Registry |
| **Terraform Module** | `gateway_service` | `infrastructure/terraform/env-{env}/main.tf` |
| **Terraform Service Name** | `gateway` | Used in resource names |
| **ECS Cluster** | `punt-btg-{env}-cluster` | Created by `ecs-platform` module |
| **ECS Service** | `punt-btg-{env}-gateway` | Full service name in AWS |
| **Container Name** | `gateway` | In task definition |
| **Target Group** | `punt-btg-{env}-gateway-tg` | ALB target group |
| **CloudWatch Logs** | `/ecs/punt-btg-{env}-gateway` | Log group |
| **GitHub Workflow** | `gateway-service-deployment.yml` | `.github/workflows/` |
| **GitHub Dispatch Event** | `deploy-gateway-service` | Repository dispatch type |

**GitHub Environment Secrets (per environment):**
- `GATEWAY_CLUSTER` = `punt-btg-dev-cluster` | `punt-btg-staging-cluster` | `punt-btg-prod-cluster`
- `GATEWAY_SERVICE` = `punt-btg-dev-gateway` | `punt-btg-staging-gateway` | `punt-btg-prod-gateway`
- `GATEWAY_ALB_URL` = Environment-specific ALB URL

---

### **Auth Server**

| Component | Name/Value | Location |
|-----------|------------|----------|
| **Source Repo** | `btg-auth-server` | GitHub: BTG-C/btg-auth-server |
| **Docker Image** | `ghcr.io/btg-c/btg-auth-server` | GitHub Container Registry |
| **Terraform Module** | `auth_service` | `infrastructure/terraform/env-{env}/main.tf` |
| **Terraform Service Name** | `auth-server` | Used in resource names |
| **ECS Cluster** | `punt-btg-{env}-cluster` | Shared with other services |
| **ECS Service** | `punt-btg-{env}-auth-server` | Full service name in AWS |
| **Container Name** | `auth-server` | In task definition |
| **Target Group** | `punt-btg-{env}-auth-server-tg` | Internal ALB target group |
| **CloudWatch Logs** | `/ecs/punt-btg-{env}-auth-server` | Log group |
| **GitHub Workflow** | `auth-server-deployment.yml` | `.github/workflows/` |
| **GitHub Dispatch Event** | `deploy-auth-server` | Repository dispatch type |

**GitHub Environment Secrets (per environment):**
- `AUTH_CLUSTER` = `btg-dev-cluster` | `btg-staging-cluster` | `btg-prod-cluster`
- `AUTH_SERVICE` = `btg-dev-auth-server` | `btg-staging-auth-server` | `btg-prod-auth-server`
- `AUTH_ALB_URL` = Internal ALB URL

---

### **Enhancer Service**

| Component | Name/Value | Location |
|-----------|------------|----------|
| **Source Repo** | `btg-enhancer-service` | GitHub: BTG-C/btg-enhancer-service |
| **Docker Image** | `ghcr.io/btg-c/btg-enhancer-service` | GitHub Container Registry |
| **Terraform Module** | `enhancer_service` | `infrastructure/terraform/env-{env}/main.tf` |
| **Terraform Service Name** | `enhancer` | Used in resource names |
| **ECS Cluster** | `btg-{env}-cluster` | Shared with other services |
| **ECS Service** | `btg-{env}-enhancer` | Full service name in AWS |
| **Container Name** | `enhancer` | In task definition |
| **Target Group** | `{env}-enhancer-tg` | Internal ALB target group |
| **CloudWatch Logs** | `/ecs/btg-{env}-enhancer` | Log group |
| **GitHub Workflow** | `enhancer-service-deployment.yml` | `.github/workflows/` |
| **GitHub Dispatch Event** | `deploy-enhancer-service` | Repository dispatch type |

**GitHub Environment Secrets (per environment):**
- `ENHANCER_CLUSTER` = `btg-dev-cluster` | `btg-staging-cluster` | `btg-prod-cluster`
- `ENHANCER_SERVICE` = `btg-dev-enhancer` | `btg-staging-enhancer` | `btg-prod-enhancer`

---

### **Score Odd Service**

| Component | Name/Value | Location |
|-----------|------------|----------|
| **Source Repo** | `btg-score-odd-service` | GitHub: BTG-C/btg-score-odd-service |
| **Docker Image** | `ghcr.io/btg-c/btg-score-odd-service` | GitHub Container Registry |
| **Terraform Module** | `score_odd_service` | `infrastructure/terraform/env-{env}/main.tf` |
| **Terraform Service Name** | `score-odd` | Used in resource names |
| **ECS Cluster** | `btg-{env}-cluster` | Shared with other services |
| **ECS Service** | `btg-{env}-score-odd` | Full service name in AWS |
| **Container Name** | `score-odd` | In task definition |
| **Target Group** | `{env}-score-odd-tg` | Internal ALB target group |
| **CloudWatch Logs** | `/ecs/btg-{env}-score-odd` | Log group |
| **GitHub Workflow** | `score-odd-service-deployment.yml` | `.github/workflows/` |
| **GitHub Dispatch Event** | `deploy-score-odd-service` | Repository dispatch type |

**GitHub Environment Secrets (per environment):**
- `SCORE_ODD_CLUSTER` = `btg-dev-cluster` | `btg-staging-cluster` | `btg-prod-cluster`
- `SCORE_ODD_SERVICE` = `btg-dev-score-odd` | `btg-staging-score-odd` | `btg-prod-score-odd`

---

## Naming Pattern

### **Terraform Resources**

```hcl
# Pattern: {project_name}-{environment}-{service_name}
resource "aws_ecs_service" "main" {
  name = "${var.project_name}-${var.environment}-${var.service_name}"
  # Example: btg-dev-gateway
}

# Log Group Pattern: /ecs/{project_name}-{environment}-{service_name}
resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${var.project_name}-${var.environment}-${var.service_name}"
  # Example: /ecs/btg-dev-gateway
}

# Target Group Pattern: {environment}-{service_name}-tg
resource "aws_lb_target_group" "main" {
  name = "${var.environment}-${var.service_name}-tg"
  # Example: dev-gateway-tg
}
```

### **GitHub Actions Workflow**

```yaml
# Workflow file: {service-name}-deployment.yml
# Example: gateway-service-deployment.yml

# Repository dispatch event: deploy-{service-name}
# Example: deploy-gateway-service

# Secrets naming:
# {SERVICE}_CLUSTER, {SERVICE}_SERVICE, {SERVICE}_ALB_URL
# Example: GATEWAY_CLUSTER, GATEWAY_SERVICE, GATEWAY_ALB_URL
```

### **Docker Images**

```bash
# Pattern: ghcr.io/{org}/{repo-name}:{tag}
# Example: ghcr.io/btg-c/btg-gateway-service:v1.2.3
```

---

## Repository Dispatch Flow

### **Step 1: Application Repo Builds Image**

```yaml
# In btg-gateway-service/.github/workflows/artifact-pipeline.yml
- name: Build and push Docker image
  run: |
    docker build -t ghcr.io/btg-c/btg-gateway-service:${{ github.sha }} .
    docker push ghcr.io/btg-c/btg-gateway-service:${{ github.sha }}

- name: Trigger deployment in DevOps repo
  run: |
    curl -X POST \
      -H "Authorization: token ${{ secrets.DEVOPS_REPO_TOKEN }}" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/BTG-C/btg-devops/dispatches \
      -d '{
        "event_type": "deploy-gateway-service",
        "client_payload": {
          "environment": "dev",
          "image_tag": "${{ github.sha }}"
        }
      }'
```

### **Step 2: DevOps Repo Deploys to ECS**

```yaml
# In btg-devops/.github/workflows/gateway-service-deployment.yml
on:
  repository_dispatch:
    types: [deploy-gateway-service]

jobs:
  deploy:
    environment: ${{ github.event.client_payload.environment }}
    steps:
      - name: Deploy to ECS
        run: |
          IMAGE="ghcr.io/btg-c/btg-gateway-service:${{ github.event.client_payload.image_tag }}"
          
          aws ecs update-service \
            --cluster ${{ secrets.GATEWAY_CLUSTER }} \
            --service ${{ secrets.GATEWAY_SERVICE }} \
            --force-new-deployment
```

---

## Service Directory Structure

```
btg-devops/
├── services/
│   ├── gateway-service/          # Java - API Gateway (Spring Cloud Gateway)
│   │   ├── config/
│   │   │   ├── dev.json          # Dev environment variables
│   │   │   ├── staging.json      # Staging environment variables
│   │   │   └── prod.json         # Prod environment variables
│   │   └── ecs/
│   │       └── task-definition-template.json
│   ├── auth-server/              # Java - OAuth2 Authorization Server
│   │   ├── config/
│   │   └── ecs/
│   ├── enhancer-service/         # Java - Business Logic Service
│   │   ├── config/
│   │   └── ecs/
│   ├── score-odd-service/        # Java - Score & Odds Service
│   │   ├── config/
│   │   └── ecs/
│   └── shell-mfe/                # Angular - Host MFE (requires runtime config)
│       ├── config/
│       │   ├── dev.json          # Backend URLs and remote entry points
│       │   ├── staging.json
│       │   └── prod.json
│       └── ecs/
```

**Note:** `enhancer-mfe` doesn't need config directory - it's a remote module loaded by shell-mfe and inherits configuration context.
├── infrastructure/
│   └── terraform/
│       ├── modules/
│       │   ├── ecs-service/      # Reusable ECS service module
│       │   ├── ecs-platform/     # Cluster, ALBs
│       │   └── networking/       # VPC, subnets
│       └── env-dev/
│           └── main.tf           # Calls ecs-service module for each service
└── .github/
    └── workflows/
        ├── gateway-service-deployment.yml
        ├── auth-server-deployment.yml
        ├── enhancer-service-deployment.yml
        └── score-odd-service-deployment.yml
```

---

## Terraform Variable Mapping

```hcl
# infrastructure/terraform/env-dev/main.tf

module "gateway_service" {
  source = "../modules/ecs-service"
  
  service_name = "gateway"  # ← Used to build: btg-dev-gateway
}

# This creates:
# - ECS Service: btg-dev-gateway
# - Target Group: dev-gateway-tg
# - Log Group: /ecs/btg-dev-gateway
# - Task Family: btg-dev-gateway
```

---

## GitHub Environment Setup

For each environment (dev, staging, prod), configure these secrets in `btg-devops` repository:

### **Development Environment**

```
Settings → Environments → dev → Secrets:

AWS_ROLE_ARN: arn:aws:iam::123456789012:role/github-actions-dev
AWS_REGION: us-east-1
AWS_ACCOUNT_ID: 123456789012

GATEWAY_CLUSTER: btg-dev-cluster
GATEWAY_SERVICE: btg-dev-gateway
GATEWAY_ALB_URL: https://gateway-dev.yourdomain.com

AUTH_CLUSTER: btg-dev-cluster
AUTH_SERVICE: btg-dev-auth-server

ENHANCER_CLUSTER: btg-dev-cluster
ENHANCER_SERVICE: btg-dev-enhancer

SCORE_ODD_CLUSTER: btg-dev-cluster
SCORE_ODD_SERVICE: btg-dev-score-odd
```

### **Staging Environment**

```
Settings → Environments → staging → Secrets:

AWS_ROLE_ARN: arn:aws:iam::987654321098:role/github-actions-staging
AWS_REGION: us-east-1
AWS_ACCOUNT_ID: 987654321098

GATEWAY_CLUSTER: btg-staging-cluster
GATEWAY_SERVICE: btg-staging-gateway
GATEWAY_ALB_URL: https://gateway-staging.yourdomain.com

AUTH_CLUSTER: btg-staging-cluster
AUTH_SERVICE: btg-staging-auth-server

ENHANCER_CLUSTER: btg-staging-cluster
ENHANCER_SERVICE: btg-staging-enhancer

SCORE_ODD_CLUSTER: btg-staging-cluster
SCORE_ODD_SERVICE: btg-staging-score-odd
```

### **Production Environment**

```
Settings → Environments → production → Secrets:

AWS_ROLE_ARN: arn:aws:iam::111222333444:role/github-actions-prod
AWS_REGION: us-east-1
AWS_ACCOUNT_ID: 111222333444

GATEWAY_CLUSTER: btg-prod-cluster
GATEWAY_SERVICE: btg-prod-gateway
GATEWAY_ALB_URL: https://gateway.yourdomain.com

AUTH_CLUSTER: btg-prod-cluster
AUTH_SERVICE: btg-prod-auth-server

ENHANCER_CLUSTER: btg-prod-cluster
ENHANCER_SERVICE: btg-prod-enhancer

SCORE_ODD_CLUSTER: btg-prod-cluster
SCORE_ODD_SERVICE: btg-prod-score-odd
```

---

## Verification Checklist

### **After Terraform Apply:**

```bash
# 1. Verify ECS Cluster exists
aws ecs describe-clusters --clusters btg-dev-cluster

# 2. Verify ECS Service exists
aws ecs describe-services \
  --cluster btg-dev-cluster \
  --services btg-dev-gateway

# 3. Verify Target Group exists
aws elbv2 describe-target-groups \
  --names dev-gateway-tg

# 4. Verify Log Group exists
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/btg-dev-gateway
```

### **After GitHub Actions Deployment:**

```bash
# 1. Check task definition revision
aws ecs describe-services \
  --cluster btg-dev-cluster \
  --services btg-dev-gateway \
  --query 'services[0].taskDefinition'

# 2. Check running tasks
aws ecs list-tasks \
  --cluster btg-dev-cluster \
  --service-name btg-dev-gateway

# 3. Check container image in use
aws ecs describe-task-definition \
  --task-definition btg-dev-gateway \
  --query 'taskDefinition.containerDefinitions[0].image'
```

---

## Common Issues

### **Issue: Service not found**

**Error:** `Service 'btg-dev-gateway-service' not found`

**Cause:** Mismatch between GitHub secret and actual ECS service name

**Solution:** 
```bash
# Find actual service name
aws ecs list-services --cluster btg-dev-cluster

# Update GitHub Environment secret to match
GATEWAY_SERVICE=btg-dev-gateway  # Not btg-dev-gateway-service
```

### **Issue: Cluster not found**

**Error:** `Cluster 'btg-cluster' not found`

**Cause:** Missing environment prefix in cluster name

**Solution:**
```bash
# Cluster name includes environment
GATEWAY_CLUSTER=btg-dev-cluster  # Not btg-cluster
```

---

## Summary

**Key Principles:**
1. ✅ Terraform creates resources with consistent naming: `{project}-{env}-{service}`
2. ✅ GitHub secrets reference these exact names (no guessing)
3. ✅ Docker images published to GHCR from app repos
4. ✅ Deployment workflows triggered via repository_dispatch from app repos
5. ✅ Service configs stored in `btg-devops/services/{service-name}/config/`

**Naming is NOT arbitrary** - it's derived from:
- **Project name** (btg) + **Environment** (dev/staging/prod) + **Service name** (gateway/auth-server/etc.)
- Terraform constructs these names automatically
- GitHub secrets must match these constructed names exactly
