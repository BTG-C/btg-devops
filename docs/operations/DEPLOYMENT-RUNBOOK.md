# Deployment Runbook

**Step-by-step guide for deploying services to dev, staging, and production environments.**

---

## Table of Contents
1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Deploy to Development](#deploy-to-development)
3. [Deploy to Staging](#deploy-to-staging)
4. [Deploy to Production](#deploy-to-production)
5. [Post-Deployment Validation](#post-deployment-validation)
6. [Monitoring](#monitoring)

---

## Pre-Deployment Checklist

### Before Every Deployment

- [ ] **Code Review:** All PRs approved and merged
- [ ] **Tests Passing:** CI pipeline green in app repo
- [ ] **Change Log:** Update `CHANGELOG.md` with changes
- [ ] **Database Migrations:** Run in target environment first (if applicable)
- [ ] **Feature Flags:** Verify flags are configured correctly
- [ ] **Secrets:** Ensure secrets exist in AWS Secrets Manager for target environment
- [ ] **Stakeholder Notification:** Inform relevant teams in Slack (#releases channel)

### Production-Specific Checks

- [ ] **Deployment Window:** Within approved window (Mon-Thu, 10am-4pm ET)
- [ ] **Approvers Available:** Confirm 2 approvers are online
- [ ] **Rollback Plan:** Know previous stable version
- [ ] **On-Call Engineer:** Verify someone is on standby
- [ ] **Load Test:** Run load test in staging first
- [ ] **Backup Verification:** Confirm database backups are recent

---

## Deploy to Development

### Automatic Deployment (Recommended)

**Trigger:** Push to `develop` branch in app repository

```powershell
# In app repo (e.g., btg-auth-server)
git checkout develop
git pull origin develop
git merge feature/your-feature
git push origin develop
```

**What Happens Automatically:**
1. App repo runs `artifact-pipeline.yml`
2. Builds Docker image with tag: `develop-abc123-20260113143052`
3. Pushes to GHCR: `ghcr.io/btg-c/btg-gateway-service:develop-abc123`
4. Triggers DevOps repo with `repository_dispatch`
5. DevOps repo runs `gateway-service-deployment.yml` or `mfe-promotion-pipeline.yml`
6. Deploys to dev environment (no approval needed)

**Timeline:** 5-10 minutes

### Manual Deployment (If Needed)

```powershell
# Gateway Service deployment
cd c:\Git\btg-devops
gh workflow run gateway-service-deployment.yml \
  -f environment=dev

# MFE deployment
gh workflow run mfe-promotion-pipeline.yml \
  -f service=shell \
  -f image_tag=develop-abc123-20260113143052 \
  -f environment=dev
```

### Watch Deployment Progress

```powershell
# Option 1: Browser
gh workflow view gateway-service-deployment.yml --web
# Or for MFEs:
gh workflow view mfe-promotion-pipeline.yml --web

# Option 2: Terminal
gh run watch
```

### Verify Deployment

```powershell
# Check service health
curl https://api-dev.btg.com/actuator/health

# Expected response:
# {"status":"UP","groups":["liveness","readiness"]}
```

---

## Deploy to Staging

### Automatic Deployment (Recommended)

**Trigger:** Push to `release/*` branch in app repository

```powershell
# In app repo (e.g., btg-auth-server)
git checkout develop
git pull origin develop

# Create release branch
git checkout -b release/v1.2.0
git push origin release/v1.2.0
```

**What Happens Automatically:**
1. App repo runs `artifact-pipeline.yml`
2. Builds Docker image with tag: `release-v1.2.0-def456-20260113150234`
3. Pushes to GHCR
4. Triggers DevOps repo
5. Deploys to staging environment (no approval needed)

**Timeline:** 5-10 minutes

### Manual Deployment

```powershell
cd c:\Git\btg-devops
# Gateway Service
gh workflow run gateway-service-deployment.yml \
  -f environment=staging

# MFE
gh workflow run mfe-promotion-pipeline.yml \
  -f service=shell \
  -f image_tag=release-v1.2.0-def456-20260113150234 \
  -f environment=staging
```

### Staging Validation Checklist

- [ ] **Smoke Tests:** Run automated smoke test suite
- [ ] **Integration Tests:** Verify service integrations work
- [ ] **Load Test:** Run load test (target: 2x production traffic)
- [ ] **Security Scan:** No critical vulnerabilities
- [ ] **Performance:** Response times within SLA (<500ms p95)
- [ ] **Monitoring:** No errors in CloudWatch logs
- [ ] **Database:** Verify migrations applied successfully

**Hold in Staging:** Minimum 2 hours before promoting to production

---

## Deploy to Production

### ⚠️ Production Deployment (Manual Only)

**Prerequisites:**
- [ ] Successfully deployed and validated in staging
- [ ] 2 approvers available (DevOps Lead + Release Manager)
- [ ] Within deployment window (Mon-Thu, 10am-4pm ET)
- [ ] No other production deployments in progress
- [ ] On-call engineer notified and standing by

### Step 1: Announce Deployment

```
#releases Slack channel:
🚀 **Production Deployment**
- Service: auth-server
- Version: v1.2.0 (image_tag: release-v1.2.0-def456-20260113150234)
- Changes: [Link to CHANGELOG.md]
- ETA: 10 minutes
- On-call: @engineer-name
```

### Step 2: Trigger Deployment

```powershell
cd c:\Git\btg-devops
# Gateway Service
gh workflow run gateway-service-deployment.yml \
  -f environment=production

# MFE
gh workflow run mfe-promotion-pipeline.yml \
  -f service=shell \
  -f image_tag=release-v1.2.0-def456-20260113150234 \
  -f environment=production
```

### Step 3: Approval Process

1. **Workflow Waits:** GitHub Environment protection rule triggers
2. **Notification:** Approvers receive GitHub notification
3. **Review:** Approvers check:
   - [ ] Staging validation passed
   - [ ] Change log reviewed
   - [ ] No active incidents
   - [ ] Within deployment window
4. **Approve:** 2 approvers click "Approve deployment"
5. **Wait Timer:** 5-minute cooling-off period
6. **Deploy:** Deployment proceeds automatically

### Step 4: Monitor Deployment

```powershell
# Watch workflow
gh run watch

# Monitor service metrics
# Open CloudWatch dashboard:
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-prod
```

**Key Metrics to Watch:**
- **ECS Tasks:** Should transition from RUNNING → DRAINING → STOPPED → RUNNING (new)
- **Error Rate:** Should remain <1%
- **Response Time:** Should remain <500ms p95
- **CPU/Memory:** Should remain <70%

### Step 5: Health Check

Wait for ECS service to stabilize (~2-5 minutes), then verify:

```powershell
# Health endpoint
curl https://api.btg.com/actuator/health

# Expected:
# {"status":"UP"}

# Metrics endpoint
curl https://api.btg.com/actuator/metrics

# Application-specific endpoint
curl https://api.btg.com/api/v1/status
```

### Step 6: Post-Deployment Monitoring

**Watch for 30 minutes:**
- [ ] No 5xx errors in ALB logs
- [ ] No exceptions in CloudWatch logs
- [ ] Response times within SLA
- [ ] No customer complaints in support channels

### Step 7: Announce Success

```
#releases Slack channel:
✅ **Production Deployment Complete**
- Service: auth-server
- Version: v1.2.0
- Status: HEALTHY
- Rollback plan: Previous version xyz789 available if needed
```

---

## Post-Deployment Validation

### Automated Checks (Run via Script)

```powershell
# Run post-deployment validation suite
.\tools\health-checks\validate-deployment.ps1 -Service auth-server -Environment production

# Expected output:
# ✅ Service health: UP
# ✅ Database connection: OK
# ✅ Dependent services: OK
# ✅ Error rate: 0.02% (< 1% threshold)
# ✅ Response time p95: 234ms (< 500ms SLA)
```

### Manual Validation

#### Backend Services (ECS)

```powershell
# 1. Check ECS service status
aws ecs describe-services \
  --cluster btg-prod-cluster \
  --services auth-server \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# Expected: status=ACTIVE, running=desired

# 2. Check task health
aws ecs list-tasks \
  --cluster btg-prod-cluster \
  --service-name auth-server \
  --desired-status RUNNING

# 3. Check CloudWatch logs (last 10 minutes)
aws logs tail /ecs/auth-server --since 10m --follow
```

#### Frontend Services (S3 + CloudFront)

```powershell
# 1. Check S3 deployment
aws s3 ls s3://btg-prod-blue/ --recursive | Select-String "index.html"

# Should show recent timestamp

# 2. Check CloudFront invalidation
aws cloudfront list-invalidations \
  --distribution-id EABCDEF123456 \
  --max-items 1

# Status should be "Completed"

# 3. Test frontend (bypass cache)
curl -H "Cache-Control: no-cache" https://btg.com/

# Should return latest version
```

### Performance Validation

```powershell
# Run load test (10 concurrent users, 100 requests)
.\tools\load-tests\run-load-test.ps1 -Service auth-server -Environment production -Duration 60s

# Expected:
# ✅ Avg response time: <300ms
# ✅ P95 response time: <500ms
# ✅ P99 response time: <1000ms
# ✅ Error rate: <1%
# ✅ Throughput: >100 req/s
```

---

## Monitoring

### Real-Time Dashboards

| Environment | Dashboard URL |
|-------------|--------------|
| **Dev** | [CloudWatch Dev Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-dev) |
| **Staging** | [CloudWatch Staging Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-staging) |
| **Production** | [CloudWatch Prod Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-prod) |

### Key Metrics

**Service Health:**
- **ECS Running Tasks:** Should match desired count
- **ECS CPU Utilization:** Should be <70%
- **ECS Memory Utilization:** Should be <70%

**Application Performance:**
- **ALB Target Response Time:** p95 <500ms
- **ALB 5xx Errors:** <1% of total requests
- **ALB Request Count:** Track traffic patterns

**Dependencies:**
- **Database Connections:** Should have available connections
- **Secret Manager API Calls:** Should not be throttled

### CloudWatch Alarms

| Alarm | Threshold | Action |
|-------|-----------|--------|
| **ECS Service Unhealthy** | <1 running task | Page on-call engineer |
| **High CPU** | >80% for 5 min | Auto-scale (if configured) + alert |
| **High Memory** | >80% for 5 min | Auto-scale (if configured) + alert |
| **High Error Rate** | >5% for 5 min | Page on-call engineer |
| **Slow Response** | p95 >1000ms for 5 min | Alert DevOps team |

### Log Analysis

```powershell
# Search for errors in last hour
aws logs filter-log-events \
  --log-group-name /ecs/auth-server \
  --start-time $(Get-Date).AddHours(-1).Ticks/10000 \
  --filter-pattern "ERROR"

# Search for specific error message
aws logs filter-log-events \
  --log-group-name /ecs/auth-server \
  --filter-pattern "\"NullPointerException\""

# Tail logs in real-time
aws logs tail /ecs/auth-server --follow
```

---

## Troubleshooting Common Issues

### Issue: Deployment Stuck in "Waiting for approval"

**Symptoms:** Workflow doesn't proceed after trigger

**Solution:**
1. Check approvers received notification: GitHub → Settings → Notifications
2. Verify approvers have write access to repository
3. Check environment protection rules are configured correctly
4. Manually approve: Go to Actions → Select run → Review deployments → Approve

---

### Issue: ECS Task Fails to Start

**Symptoms:** Task goes from PENDING → STOPPED immediately

**Solution:**
```powershell
# Get task failure reason
aws ecs describe-tasks \
  --cluster btg-prod-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].stopCode'

# Common causes:
# - "EssentialContainerExited" → Check CloudWatch logs for app errors
# - "CannotPullContainerError" → GHCR authentication failed
# - "ResourceInitializationError" → Secrets Manager access denied
```

---

### Issue: Health Check Fails After Deployment

**Symptoms:** ECS shows task UNHEALTHY, gets replaced repeatedly

**Solution:**
```powershell
# Check health check endpoint manually
kubectl run debug --rm -it --image=curlimages/curl -- \
  curl http://<task-private-ip>:9000/actuator/health

# If returns 503 or timeout:
# - Check application logs for startup errors
# - Verify secrets are fetched correctly
# - Ensure health check path is correct in task definition
```

---

## Emergency Procedures

### If Deployment Fails

**Immediate Actions:**
1. **DO NOT** try to fix forward immediately
2. **Rollback** to previous stable version (see [Rollback Procedures](ROLLBACK-PROCEDURES.md))
3. **Notify** stakeholders in #incidents Slack channel
4. **Investigate** root cause after service is stable

### If Production is Down

**Critical Incident Response:**
1. **Page** on-call engineer immediately
2. **Assess** impact (% of users affected)
3. **Decide:** Rollback vs forward-fix vs hotfix
4. **Execute:** Follow [Incident Response Playbook](../troubleshooting/INCIDENT-RESPONSE.md)
5. **Communicate:** Post updates every 15 minutes in #incidents

---

## Deployment Schedule

### Allowed Windows

| Environment | Days | Times (ET) | Approval |
|-------------|------|------------|----------|
| **Dev** | Mon-Sun | Anytime | None |
| **Staging** | Mon-Sun | Anytime | None |
| **Production** | Mon-Thu | 10am-4pm | 2 required |

### Blackout Periods (No Production Deployments)

- **Fridays** (risk of weekend incidents)
- **Before holidays** (48 hours before)
- **During major events** (e.g., Super Bowl Sunday for betting apps)
- **Active incidents** (P1/P2 severity)

---

## References

- [Rollback Procedures](ROLLBACK-PROCEDURES.md)
- [Monitoring & Alerting](MONITORING.md)
- [Disaster Recovery](DISASTER-RECOVERY.md)
- [Incident Response](../troubleshooting/INCIDENT-RESPONSE.md)

---

**Last Updated:** 2026-01-13  
**Review Cycle:** Monthly  
**Document Owner:** Release Manager
