# Gateway Service Deployment Configuration

**ECS Fargate deployment for btg-gateway-service (Spring Boot)**

---

## Overview

- **Type:** Backend service (Spring Boot + Spring Cloud Gateway)
- **Hosting:** AWS ECS Fargate
- **Container Registry:** GitHub Container Registry (GHCR)
- **Repository:** [btg-gateway-service](https://github.com/BTG-C/btg-gateway-service)

---

## Directory Structure

```
services/gateway-service/
├── README.md                           # This file
└── ecs/
    ├── task-definition-template.json   # ECS task definition with placeholders
    └── service-definition.yaml         # ECS service configuration
```

---

## JVM Configuration Strategy

### **Dockerfile (Immutable)**
```dockerfile
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
```
- Only universal flags that never change
- Keeps Docker image identical across all environments

### **ECS Task Definition (Environment-Specific)**
```json
{
  "name": "JAVA_TOOL_OPTIONS",
  "value": "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
}
```
- Memory and performance tuning per environment
- Can override without rebuilding image

### **Why This Split?**
✅ **Immutability:** Same Docker image deployed to dev/staging/prod  
✅ **Flexibility:** Tune JVM per environment without rebuild  
✅ **Debugging:** Override flags in ECS console without code changes  
✅ **Cost:** Dev uses less memory, prod uses more  

---

## Environment-Specific Configurations

### **Development**
```yaml
CPU: 512 (0.5 vCPU)
Memory: 1024 MB (1 GB)
Desired Count: 1
Auto-scaling: Disabled
JAVA_TOOL_OPTIONS: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
  # Heap: ~750 MB (75% of 1 GB)
```

### **Staging**
```yaml
CPU: 1024 (1 vCPU)
Memory: 2048 MB (2 GB)
Desired Count: 2
Auto-scaling: 2-6 tasks
JAVA_TOOL_OPTIONS: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
  # Heap: ~1.5 GB (75% of 2 GB)
```

### **Production**
```yaml
CPU: 2048 (2 vCPU)
Memory: 4096 MB (4 GB)
Desired Count: 3
Auto-scaling: 3-20 tasks
JAVA_TOOL_OPTIONS: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -XX:+HeapDumpOnOutOfMemoryError"
  # Heap: ~3 GB (75% of 4 GB)
```

---

## Task Definition Placeholders

| Placeholder | Source | Example Value |
|------------|--------|---------------|
| `{{IMAGE_TAG}}` | `client_payload.image_tag` | `v1.2.3` or `develop-abc123` |
| `{{ENVIRONMENT}}` | GitHub Environment name | `dev`, `staging`, `production` |
| `{{AWS_REGION}}` | GitHub Environment secret | `us-east-1` |
| `{{AWS_ACCOUNT_ID}}` | GitHub Environment secret | `123456789012` |

**Replacement happens in:** `.github/workflows/gateway-service-deployment.yml`

---

## Secrets Configuration

### **AWS Secrets Manager** (Sensitive values - runtime injection)
```
/btg/dev/mongodb-uri          → mongodb://dev.btg.com:27017/btg
/btg/dev/jwt-secret           → eyJhbGciOiJIUzI1...
/btg/dev/gateway-client-secret → oauth-secret-dev
```

### **AWS SSM Parameter Store** (Non-sensitive values)
```
/btg/dev/auth-server-url      → https://auth-dev.btg.com
```

### **ECS Task Definition** (References secrets by ARN)
```json
"secrets": [
  {
    "name": "MONGODB_URI",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:btg/dev/mongodb-uri"
  }
]
```

**Flow:** ECS task role → Fetch from Secrets Manager → Inject as env var → Spring Boot reads

---

## Deployment Flow

```
btg-gateway-service repo (push to develop)
  ↓
Build artifact pipeline (.github/workflows/artifact-pipeline.yml)
  ↓
Build JAR with Maven + Build Docker image + Push to GHCR
  ↓
Trigger btg-devops via repository_dispatch
  ↓
btg-devops deployment pipeline (.github/workflows/gateway-service-deployment.yml)
  ↓
Pull image from GHCR + Replace task definition placeholders
  ↓
Register new task definition + Update ECS service
  ↓
ECS Fargate: Pull image + Inject secrets + Start container
  ↓
Health check + Smoke test validation
```

---

## Health Checks

### **Docker Health Check** (Dockerfile)
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
```

### **ECS Task Health Check** (task-definition.json)
```json
"healthCheck": {
  "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

### **ALB Target Group Health Check**
- Path: `/actuator/health`
- Interval: 30 seconds
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 3 consecutive failures

---

## Auto-Scaling Policies

### **CPU-Based Scaling**
```yaml
Metric: ECSServiceAverageCPUUtilization
Target: 70%
Scale Out Cooldown: 60 seconds
Scale In Cooldown: 300 seconds (5 minutes)
```

### **Memory-Based Scaling**
```yaml
Metric: ECSServiceAverageMemoryUtilization
Target: 80%
Scale Out Cooldown: 60 seconds
Scale In Cooldown: 300 seconds
```

### **Request-Based Scaling**
```yaml
Metric: ALBRequestCountPerTarget
Target: 1000 requests/minute per task
Scale Out Cooldown: 60 seconds
Scale In Cooldown: 300 seconds
```

---

## Monitoring & Alarms

### **CloudWatch Alarms**
- `gateway-cpu-high` → CPU > 85% for 2 periods
- `gateway-memory-high` → Memory > 90% for 2 periods
- `gateway-unhealthy-targets` → Unhealthy count > 0 for 2 periods
- `gateway-response-time` → P99 latency > 2 seconds

### **CloudWatch Logs**
- Log Group: `/ecs/btg-gateway-service`
- Stream Prefix: `dev` / `staging` / `production`
- Retention: 30 days (dev), 90 days (prod)

---

## Troubleshooting

### **Container Won't Start**
1. Check CloudWatch logs: `/ecs/btg-gateway-service`
2. Verify secrets exist in Secrets Manager
3. Check task role has `secretsmanager:GetSecretValue` permission
4. Verify image exists in GHCR: `docker pull ghcr.io/btg-c/btg-gateway-service:TAG`

### **OOM Kills (Out of Memory)**
1. Check memory usage in CloudWatch: `ECSServiceAverageMemoryUtilization`
2. Increase task memory in `service-definition.yaml`
3. Adjust `MaxRAMPercentage` in `JAVA_TOOL_OPTIONS` (lower from 75% to 70%)
4. Check for memory leaks (heap dumps enabled in prod)

### **Slow Startup**
1. Increase `startPeriod` in health check (current: 60s)
2. Check `/actuator/health` response time
3. Reduce `InitialRAMPercentage` to allocate heap faster

### **Deployment Stuck**
1. Check ECS service events: `aws ecs describe-services`
2. Verify new tasks pass health checks
3. Check ALB target group health
4. Review circuit breaker settings (may auto-rollback)

---

## Related Documentation

- [Gateway Service Architecture](../../btg-gateway-service/docs/GATEWAY_ARCHITECTURE.md)
- [Complete System Architecture](../../btg-gateway-service/docs/COMPLETE_SYSTEM_ARCHITECTURE.md)
- [AWS ALB Architecture](../../btg-gateway-service/docs/AWS_ALB_ARCHITECTURE.md)
- [GitHub Environments Setup](../../docs/development/GITHUB-ENVIRONMENTS-GATEWAY.md)
- [Deployment Runbook](../../docs/operations/DEPLOYMENT-RUNBOOK.md)
