# Configuration Flow: GitHub Environments → Task Definition → ECS

**Understanding how configuration values flow from GitHub to running containers**

---

## Overview

The deployment workflow acts as a **bridge** between GitHub Environment secrets and AWS ECS, translating configuration values and injecting them into task definitions.

```
┌─────────────────────┐
│ GitHub Environments │  (Secrets storage)
│  - AWS_REGION       │
│  - AWS_ACCOUNT_ID   │
│  - GATEWAY_CLUSTER  │
└──────────┬──────────┘
           │
           │ ① Workflow reads secrets
           ↓
┌─────────────────────┐
│ Deployment Workflow │  (Bridge/Translator)
│ gateway-service-    │
│ deployment.yml      │
└──────────┬──────────┘
           │
           │ ② sed replaces {{PLACEHOLDERS}}
           ↓
┌─────────────────────┐
│ Task Definition     │  (Template → Final)
│ template.json       │
└──────────┬──────────┘
           │
           │ ③ aws ecs register-task-definition
           ↓
┌─────────────────────┐
│ AWS ECS Service     │  (Runtime)
│ Container starts    │
│ with env vars       │
└─────────────────────┘
```

---

## Configuration Types

### **1. Non-Sensitive Values (GitHub Environment → Workflow → Task Definition)**

**Source:** GitHub Environments (UI)
```
Settings → Environments → production → Secrets:
  AWS_REGION: us-east-1
  AWS_ACCOUNT_ID: 987654321098
  GATEWAY_CLUSTER: btg-prod-cluster
```

**Task Definition Template:**
```json
{
  "environment": [
    {"name": "ENVIRONMENT", "value": "{{ENVIRONMENT}}"},
    {"name": "AWS_REGION", "value": "{{AWS_REGION}}"}
  ]
}
```

**Workflow Replaces:**
```yaml
- name: Prepare task definition
  run: |
    sed -i "s|{{ENVIRONMENT}}|production|g" task-definition.json
    sed -i "s|{{AWS_REGION}}|${{ secrets.AWS_REGION }}|g" task-definition.json
```

**Final Task Definition (sent to AWS):**
```json
{
  "environment": [
    {"name": "ENVIRONMENT", "value": "production"},
    {"name": "AWS_REGION", "value": "us-east-1"}
  ]
}
```

**Container Runtime:**
```bash
# ECS injects these as environment variables
ENVIRONMENT=production
AWS_REGION=us-east-1
```

---

### **2. Sensitive Values (AWS Secrets Manager → ECS → Container)**

**Source:** AWS Secrets Manager
```bash
aws secretsmanager create-secret \
  --name btg/prod/mongodb-uri \
  --secret-string "mongodb://prod-user:SecurePassword123@prod.btg.com:27017/btg"
```

**Task Definition Template:**
```json
{
  "secrets": [
    {
      "name": "MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:{{AWS_REGION}}:{{AWS_ACCOUNT_ID}}:secret:btg/{{ENVIRONMENT}}/mongodb-uri"
    }
  ]
}
```

**Workflow Replaces (only the ARN path, not the secret value):**
```yaml
- name: Prepare task definition
  run: |
    sed -i "s|{{AWS_REGION}}|us-east-1|g" task-definition.json
    sed -i "s|{{AWS_ACCOUNT_ID}}|987654321098|g" task-definition.json
    sed -i "s|{{ENVIRONMENT}}|production|g" task-definition.json
```

**Final Task Definition:**
```json
{
  "secrets": [
    {
      "name": "MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:987654321098:secret:btg/production/mongodb-uri"
    }
  ]
}
```

**Container Runtime:**
```bash
# ECS uses task role to fetch from Secrets Manager at container start
# Never passes through GitHub
MONGODB_URI=mongodb://prod-user:SecurePassword123@prod.btg.com:27017/btg
```

---

## Step-by-Step Flow

### **Step 1: GitHub Environment Configuration**

**Location:** `btg-devops` repository → Settings → Environments → `production`

**Configured values:**
```yaml
AWS_ACCOUNT_ID: "987654321098"
AWS_REGION: "us-east-1"
AWS_ROLE_ARN: "arn:aws:iam::987654321098:role/github-actions-prod"
GATEWAY_CLUSTER: "btg-prod-cluster"
GATEWAY_SERVICE: "btg-gateway-service"
GATEWAY_ALB_URL: "https://api.btg.com"
```

**Protection rules:**
- ✅ Required reviewers: 2
- ✅ Wait timer: 5 minutes
- ✅ Branch restriction: `main` only

---

### **Step 2: Workflow Triggered**

**Trigger:** Repository dispatch from app repo after Docker image build

```yaml
# In btg-gateway-service artifact-pipeline.yml
- name: Trigger DevOps deployment
  run: |
    curl -X POST \
      https://api.github.com/repos/BTG-C/btg-devops/dispatches \
      -d '{
        "event_type": "deploy-gateway-service",
        "client_payload": {
          "environment": "production",
          "image_tag": "v1.2.3"
        }
      }'
```

---

### **Step 3: Workflow Reads GitHub Environment Secrets**

**Workflow:** `.github/workflows/gateway-service-deployment.yml`

```yaml
jobs:
  deploy:
    environment: production  # ← Grants access to production secrets
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # ← Read from GitHub Environment
          aws-region: ${{ secrets.AWS_REGION }}        # ← Read from GitHub Environment
```

---

### **Step 4: Workflow Replaces Placeholders**

```yaml
# NOTE: This is a historical example. Current implementation uses:
# 1. Terraform to create initial ECS service configuration
# 2. GitHub Actions fetch live task definition from AWS
# 3. Dynamic image update without template files

# Example (for reference only - not used in actual workflows):
- name: Prepare task definition
  run: |
    ENV_NAME="production"
    IMAGE_TAG="v1.2.3"
    
    # Fetch current task definition from AWS (actual approach)
    aws ecs describe-task-definition \
      --task-definition gateway-service \
      --query taskDefinition > task-definition.json
    
    # Update image using jq
    jq --arg IMAGE "ghcr.io/btg-c/gateway-service:$IMAGE_TAG" \
       '.containerDefinitions[0].image = $IMAGE' \
       task-definition.json > new-task-definition.json
```

**Before:**
```json
{
  "image": "ghcr.io/btg-c/btg-gateway-service:{{IMAGE_TAG}}",
  "environment": [
    {"name": "AWS_REGION", "value": "{{AWS_REGION}}"}
  ],
  "secrets": [
    {
      "name": "MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:{{AWS_REGION}}:{{AWS_ACCOUNT_ID}}:secret:btg/{{ENVIRONMENT}}/mongodb-uri"
    }
  ]
}
```

**After:**
```json
{
  "image": "ghcr.io/btg-c/btg-gateway-service:v1.2.3",
  "environment": [
    {"name": "AWS_REGION", "value": "us-east-1"}
  ],
  "secrets": [
    {
      "name": "MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:987654321098:secret:btg/production/mongodb-uri"
    }
  ]
}
```

---

### **Step 5: Register Task Definition with ECS**

```yaml
- name: Register task definition
  run: |
    TASK_DEF_ARN=$(aws ecs register-task-definition \
      --cli-input-json file://task-definition.json \
      --query 'taskDefinition.taskDefinitionArn' \
      --output text)
```

**What happens:**
- Task definition stored in AWS ECS
- GitHub is no longer involved
- AWS now owns this configuration

---

### **Step 6: Update ECS Service**

```yaml
- name: Update ECS service
  run: |
    aws ecs update-service \
      --cluster ${{ secrets.GATEWAY_CLUSTER }} \
      --service ${{ secrets.GATEWAY_SERVICE }} \
      --task-definition $TASK_DEF_ARN \
      --force-new-deployment
```

---

### **Step 7: ECS Starts Container**

**Container startup sequence:**

1. **ECS pulls Docker image:**
   ```bash
   docker pull ghcr.io/btg-c/btg-gateway-service:v1.2.3
   ```

2. **ECS injects environment variables:**
   ```bash
   docker run \
     -e ENVIRONMENT=production \
     -e AWS_REGION=us-east-1 \
     -e JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" \
     ...
   ```

3. **ECS task role fetches secrets from AWS Secrets Manager:**
   ```bash
   # Task role has secretsmanager:GetSecretValue permission
   MONGODB_URI=$(aws secretsmanager get-secret-value \
     --secret-id btg/production/mongodb-uri \
     --query SecretString \
     --output text)
   ```

4. **ECS injects secrets as environment variables:**
   ```bash
   docker run \
     -e MONGODB_URI="mongodb://actual-password" \
     -e JWT_SECRET="actual-jwt-secret" \
     ...
   ```

5. **Spring Boot application starts and reads environment variables:**
   ```yaml
   # application.yaml
   spring:
     data:
       mongodb:
         uri: ${MONGODB_URI}  # ← Reads from environment variable
   ```

---

## Security Model

### **What's in GitHub:**
- ✅ AWS account IDs (non-sensitive identifiers)
- ✅ AWS region names (public information)
- ✅ Cluster/service names (internal names, not sensitive)
- ✅ IAM role ARNs (paths, not credentials)
- ❌ NO passwords
- ❌ NO API keys
- ❌ NO database credentials

### **What's in AWS Secrets Manager:**
- ✅ Database passwords
- ✅ JWT signing secrets
- ✅ OAuth client secrets
- ✅ API keys

### **What's in Task Definition (after registration):**
- ✅ Environment variable values (non-sensitive)
- ✅ Secret ARN paths (not actual secrets)
- ❌ NO actual secret values

### **What's in Container:**
- ✅ All environment variables
- ✅ All secrets (fetched at runtime)
- ⚠️ Secrets only in memory, never on disk

---

## Why This Pattern?

### **✅ Advantages:**

1. **Separation of Concerns:**
   - GitHub manages deployment config
   - AWS manages runtime secrets
   - No overlap, clear boundaries

2. **Security:**
   - Secrets never touch GitHub
   - No secrets in Git history
   - No secrets in workflow logs
   - Secrets encrypted at rest (AWS) and in transit (TLS)

3. **Immutability:**
   - Same Docker image runs everywhere
   - Only config changes per environment
   - No rebuilds for config changes

4. **Auditability:**
   - GitHub: Who approved production deployment
   - AWS CloudTrail: Who accessed secrets
   - ECS: Which task definition version is running

5. **Flexibility:**
   - Change secrets in AWS without redeployment
   - Change non-sensitive config in GitHub Environments
   - Rotate secrets automatically

### **✅ Production-Ready:**
- SOC2 compliant
- ISO27001 compliant
- GDPR compliant
- Follows AWS Well-Architected Framework
- Follows 12-Factor App methodology

---

## Troubleshooting

### **Problem: Placeholders not replaced**

**Symptom:** Task definition contains `{{ENVIRONMENT}}` after deployment

**Cause:** Workflow sed command failed or wrong syntax

**Solution:**
```bash
# Check workflow logs for sed errors
# Verify placeholder syntax matches: {{PLACEHOLDER}} not ${PLACEHOLDER}
```

---

### **Problem: ECS can't fetch secrets**

**Symptom:** Container fails to start with "Unable to fetch secret" error

**Cause:** Task role missing `secretsmanager:GetSecretValue` permission

**Solution:**
```json
// Add to task role policy
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:*:*:secret:btg/production/*"
}
```

---

### **Problem: Wrong environment values**

**Symptom:** Production container using dev database

**Cause:** Workflow triggered with wrong environment name

**Solution:**
```yaml
# Verify repository_dispatch sends correct environment
"client_payload": {
  "environment": "production"  # ← Must match GitHub Environment name
}
```

---

## Related Documentation

- [GitHub Environments Setup](./GITHUB-ENVIRONMENTS-GATEWAY.md)
- [Gateway Service Configuration](../../services/gateway-service/README.md)
- [Deployment Runbook](../operations/DEPLOYMENT-RUNBOOK.md)
- [AWS Secrets Manager Setup](../infrastructure/AWS-SETUP.md)
