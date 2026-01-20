# Configuration Flow

**How configuration flows from Git to running containers in AWS ECS**

---

## Simple Overview

```
App Repo                DevOps Repo               AWS
┌──────────┐           ┌──────────┐           ┌─────────┐
│ Build    │──push────>│ Workflow │──deploy──>│   ECS   │
│ Docker   │  event    │ Injects  │           │ Service │
│ Image    │           │ Config   │           └─────────┘
└──────────┘           └──────────┘
                            │
                            │ reads
                            ↓
                     services/{service}/
                     ├── config/
                     │   ├── dev.json
                     │   ├── staging.json
                     │   └── prod.json
                     └── ecs/
                         └── task-definition-template.json
```

---

## Configuration Structure

### 1. Config Files (Per Environment)

**Location:** `services/{service}/config/{env}.json`

**Purpose:** Store environment-specific, non-sensitive values

**Example:** `services/gateway-service/config/dev.json`
```json
{
  "envVars": {
    "AUTH_SERVER_URL": "http://internal-btg-dev-auth-alb.us-east-1.elb.amazonaws.com:9000",
    "GATEWAY_URL": "https://api-dev.btgcric.com",
    "LOG_LEVEL": "DEBUG"
  },
  "secrets": {
    "MONGODB_URI": "btg/dev/mongodb-uri",
    "GATEWAY_CLIENT_SECRET": "btg/dev/gateway-client-secret"
  }
}
```

**What goes here:**
- ✅ Service URLs (internal ALBs, public gateways)
- ✅ CORS origins
- ✅ Log levels
- ✅ Feature flags
- ✅ Secret **references** (paths in Secrets Manager)
- ❌ Actual passwords (use Secrets Manager)

---

### 2. Task Definition Templates

**Location:** `services/{service}/ecs/task-definition-template.json`

**Purpose:** ECS task definition with placeholders

**Placeholders:**
- `{{ENVIRONMENT}}` → `dev`, `staging`, `prod`
- `{{IMAGE_TAG}}` → Docker image tag from build
- `{{AWS_ACCOUNT_ID}}` → AWS account number
- `{{AWS_REGION}}` → AWS region

**Example:**
```json
{
  "family": "btg-{{ENVIRONMENT}}-gateway-service",
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [{
    "name": "gateway-service",
    "image": "ghcr.io/btg-c/btg-gateway-service:{{IMAGE_TAG}}",
    "environment": [
      {"name": "SPRING_PROFILES_ACTIVE", "value": "{{ENVIRONMENT}}"},
      {"name": "AWS_REGION", "value": "{{AWS_REGION}}"}
    ],
    "secrets": [
      {
        "name": "MONGODB_URI",
        "valueFrom": "arn:aws:secretsmanager:{{AWS_REGION}}:{{AWS_ACCOUNT_ID}}:secret:btg/{{ENVIRONMENT}}/mongodb-uri"
      }
    ]
  }]
}
```

---

### 3. Secrets in AWS Secrets Manager

**Purpose:** Store actual sensitive values

**Naming Convention:** `btg/{environment}/{secret-name}`

**Examples:**
```bash
# MongoDB connection strings
btg/dev/mongodb-uri
btg/staging/mongodb-uri
btg/prod/mongodb-uri

# OAuth client secrets
btg/dev/gateway-client-secret
btg/staging/gateway-client-secret
btg/prod/gateway-client-secret
```

**How to create:**
```bash
aws secretsmanager create-secret \
  --name btg/dev/mongodb-uri \
  --secret-string "mongodb://user:pass@host:27017/db"
```

---

## Deployment Flow

### Step 1: Trigger Deployment

**From app repo** (e.g., `btg-gateway-service`):
```yaml
- name: Trigger deployment
  run: |
    curl -X POST https://api.github.com/repos/BTG-C/btg-devops/dispatches \
      -d '{
        "event_type": "deploy-gateway-service",
        "client_payload": {
          "environment": "dev",
          "image_tag": "sha-abc123"
        }
      }'
```

### Step 2: Workflow Prepares Task Definition

**Workflow:** `.github/workflows/gateway-service-deployment.yml`

```yaml
- name: Load configuration
  run: |
    CONFIG_FILE="services/gateway-service/config/${{ env.ENV_NAME }}.json"
    jq -r '.envVars | to_entries[] | "\(.key)=\(.value)"' $CONFIG_FILE > env_vars.txt

- name: Prepare task definition
  run: |
    # Copy template
    cp services/gateway-service/ecs/task-definition-template.json task-def.json
    
    # Replace placeholders
    sed -i "s/{{ENVIRONMENT}}/dev/g" task-def.json
    sed -i "s|{{IMAGE_TAG}}|sha-abc123|g" task-def.json
    sed -i "s/{{AWS_ACCOUNT_ID}}/123456789012/g" task-def.json
    sed -i "s/{{AWS_REGION}}/us-east-1/g" task-def.json
    
    # Inject environment variables from config
    CONFIG_ENV=$(jq -r '.envVars | to_entries | map({name: .key, value: .value})' $CONFIG_FILE)
    TEMP_ENV=$(jq '.containerDefinitions[0].environment' task-def.json)
    MERGED_ENV=$(jq -n --argjson a "$TEMP_ENV" --argjson b "$CONFIG_ENV" '$a + $b | unique_by(.name)')
    jq --argjson env "$MERGED_ENV" '.containerDefinitions[0].environment = $env' task-def.json > final-task-def.json
```

**Result:** Final task definition with:
- ✅ Correct image tag
- ✅ Environment-specific URLs and settings
- ✅ Secret ARNs pointing to correct environment

### Step 3: Deploy to ECS

```yaml
- name: Deploy to ECS
  run: |
    # Register new task definition
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
      --cli-input-json file://final-task-def.json \
      --query 'taskDefinition.taskDefinitionArn' \
      --output text)
    
    # Update service with new task definition
    aws ecs update-service \
      --cluster btg-dev-cluster \
      --service btg-dev-gateway-service \
      --task-definition $NEW_TASK_DEF_ARN \
      --force-new-deployment
    
    # Wait for stability
    aws ecs wait services-stable \
      --cluster btg-dev-cluster \
      --services btg-dev-gateway-service
```

### Step 4: ECS Fetches Secrets

When container starts:
1. ECS Task Execution Role reads secret ARNs from task definition
2. Fetches actual secret values from Secrets Manager
3. Injects as environment variables into container

**Container sees:**
```bash
MONGODB_URI=mongodb://user:SecurePass123@prod-db:27017/btg
GATEWAY_CLIENT_SECRET=super-secret-client-value
```

---

## Configuration Change Workflow

### Updating Non-Sensitive Values

**Example:** Change log level from DEBUG to INFO

1. **Edit config file:**
```bash
# services/gateway-service/config/dev.json
{
  "envVars": {
    "LOG_LEVEL": "INFO"  # Changed from DEBUG
  }
}
```

2. **Commit and push:**
```bash
git add services/gateway-service/config/dev.json
git commit -m "Change gateway log level to INFO in dev"
git push
```

3. **Redeploy service:**
   - Trigger deployment from app repo, OR
   - Manual workflow dispatch in `btg-devops`

### Updating Secrets

**Example:** Rotate MongoDB password

1. **Update secret in AWS:**
```bash
aws secretsmanager update-secret \
  --secret-id btg/dev/mongodb-uri \
  --secret-string "mongodb://user:NewPassword456@host:27017/db"
```

2. **Force ECS to restart containers:**
```bash
aws ecs update-service \
  --cluster btg-dev-cluster \
  --service btg-dev-gateway-service \
  --force-new-deployment
```

**Note:** No code or config changes needed - ECS fetches new secret on container start

---

## Best Practices

### ✅ DO

- **Version control config changes:** Commit config files to Git
- **Use PR reviews:** Config changes go through pull requests
- **Separate secrets:** Never put passwords in config files
- **Use consistent naming:** Follow `btg/{env}/{secret}` pattern
- **Test in dev first:** Validate changes before staging/prod

### ❌ DON'T

- **Hard-code secrets:** Always use Secrets Manager
- **Skip environments:** Don't deploy directly to prod
- **Duplicate config:** Use template + config files, not separate templates per environment
- **Over-engineer:** Keep config structure simple

---

## Troubleshooting

### Container fails to start with "Cannot connect to database"

**Check:**
1. Secret exists in Secrets Manager
2. Secret ARN in task definition is correct
3. Task Role has `secretsmanager:GetSecretValue` permission
4. Secret value format is correct (connection string syntax)

### Config changes not applied

**Solution:**
1. Verify config file was committed and pushed
2. Check workflow logs - was config loaded?
3. Ensure `sed` replacements worked (check task definition in ECS console)
4. Force new deployment if task definition wasn't updated

### Different values in dev vs prod

**Expected:** This is by design. Compare config files:
```bash
diff services/gateway-service/config/dev.json \
     services/gateway-service/config/prod.json
```

---

## Quick Reference

### Config File Structure
```json
{
  "envVars": {
    "KEY": "value"
  },
  "secrets": {
    "SECRET_NAME": "btg/{env}/secret-path"
  }
}
```

### Task Definition Placeholders
- `{{ENVIRONMENT}}` - Environment name
- `{{IMAGE_TAG}}` - Docker image version
- `{{AWS_ACCOUNT_ID}}` - AWS account ID
- `{{AWS_REGION}}` - AWS region

### Service Naming
- Cluster: `btg-{env}-cluster`
- Service: `btg-{env}-{service-name}`
- Task Family: `btg-{env}-{service-name}`

### Secret Naming
- Pattern: `btg/{environment}/{secret-name}`
- Example: `btg/prod/mongodb-uri`

          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # ← Read from GitHub Environment
          aws-region: ${{ secrets.AWS_REGION }}        # ← Read from GitHub Environment
```

---

### **Step 4: Workflow Updates Task Definition**

**Current Implementation:**

```yaml
- name: Deploy to ECS
  run: |
    IMAGE_TAG="${{ github.event.client_payload.image_tag }}"
    
    # 1. Fetch current task definition from AWS
    # This preserves ALL existing configuration (env vars, secrets, resources)
    aws ecs describe-task-definition \
      --task-definition ${{ secrets.GATEWAY_SERVICE }} \
      --query taskDefinition > task-def.json
    
    # 2. Update ONLY the image field using jq
    # Everything else remains unchanged
    jq --arg IMAGE "ghcr.io/btg-c/btg-gateway-service:$IMAGE_TAG" \
       '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
       task-def.json > new-task-def.json
```

**Example: What Gets Updated**

**Original Task Definition (from Terraform initial setup):**
```json
{
  "family": "btg-prod-gateway",
  "image": "ghcr.io/btg-c/btg-gateway-service:v1.0.0",
  "environment": [
    {"name": "SPRING_PROFILES_ACTIVE", "value": "prod"},
    {"name": "AWS_REGION", "value": "us-east-1"},
    {"name": "AUTH_SERVER_URL", "value": "http://internal-auth-alb:9000"}
  ],
  "secrets": [
    {
      "name": "GATEWAY_CLIENT_SECRET",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/prod/gateway-client-secret"
    }
  ]
}
```

**After Workflow Updates (new revision):**
```json
{
  "family": "btg-prod-gateway",
  "image": "ghcr.io/btg-c/btg-gateway-service:v1.2.3",  // ← ONLY THIS CHANGED
  "environment": [
    {"name": "SPRING_PROFILES_ACTIVE", "value": "prod"},
    {"name": "AWS_REGION", "value": "us-east-1"},
    {"name": "AUTH_SERVER_URL", "value": "http://internal-auth-alb:9000"}
  ],
  "secrets": [
    {
      "name": "GATEWAY_CLIENT_SECRET",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/prod/gateway-client-secret"
    }
  ]
}
```

**Key Benefits:**
- ✅ **No template files** - fetches live configuration from AWS
- ✅ **Preserves all settings** - env vars, secrets, resources unchanged
- ✅ **Supports manual updates** - if you change config in AWS Console, it persists
- ✅ **Simple deployment** - only updates Docker image tag

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
