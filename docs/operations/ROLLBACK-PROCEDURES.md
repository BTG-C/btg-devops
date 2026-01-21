# Rollback Procedures

**Emergency guide for rolling back failed deployments.**

---

## When to Rollback

### Rollback Criteria

✅ **Rollback if:**
- Service health check fails after deployment
- Error rate spikes >5%
- Critical bug affecting >10% of users
- Performance degradation (p95 >2x baseline)
- Database corruption or data loss risk
- Security vulnerability introduced

❌ **Don't rollback for:**
- Minor UI bugs (forward-fix instead)
- Single user reports (investigate first)
- Non-critical features not working
- Cosmetic issues

**Golden Rule:** When in doubt, rollback. You can always redeploy after fixing the issue.

---

## Quick Rollback (5 Minutes)

### Step 1: Find Previous Stable Version

```powershell
# List recent Gateway Service deployments
cd c:\Git\btg-devops
gh run list --workflow=gateway-service-deployment.yml --limit 10

# Find last successful production deployment
gh run list --workflow=gateway-service-deployment.yml --json conclusion,headSha,createdAt,displayTitle | ConvertFrom-Json | Where-Object { $_.conclusion -eq "success" -and $_.displayTitle -like "*production*" } | Select-Object -First 1

# For MFEs, use mfe-promotion-pipeline.yml instead
gh run list --workflow=mfe-promotion-pipeline.yml --limit 10

# Example output:
# createdAt: 2026-01-12T15:30:00Z
# displayTitle: Deploy gateway-service to production
# headSha: xyz789abc123
```

### Step 2: Identify Image Tag

```powershell
# Option 1: Check GitHub Actions run details
gh run view <run-id> --log

# Look for line like:
# Image tag: release-v1.1.0-xyz789-20260112-153000

# Option 2: Check GHCR directly
gh api -H "Accept: application/vnd.github+json" \
  /orgs/BTG-C/packages/container/btg-gateway-service/versions \
  | jq -r '.[] | select(.metadata.container.tags[] | contains("release")) | .metadata.container.tags[0]' \
  | head -5

# Shows last 5 release tags
```

### Step 3: Trigger Rollback

```powershell
# Gateway Service: Redeploy previous version
gh workflow run gateway-service-deployment.yml \
  -f environment=production
# Note: Must update GATEWAY_IMAGE_TAG in GitHub Environment first

# MFE: Redeploy previous version  
gh workflow run mfe-promotion-pipeline.yml \
  -f service=shell \
  -f image_tag=release-v1.1.0-xyz789-20260112-153000 \
  -f environment=production
```

### Step 4: Approve Rollback

**Production rollback requires 2 approvals (same as deployment)**

1. Go to: https://github.com/BTG-C/btg-devops/actions
2. Click on running workflow
3. Click "Review deployments"
4. Select "production" environment
5. Enter comment: "Approved: Rollback to stable version due to [reason]"
6. Click "Approve and deploy"
7. Wait for 2nd approver to do the same

**Approval Bypass (Emergency Only):**
If approvers are unavailable during P1 incident, DevOps Lead can temporarily remove protection rules:
```powershell
# Settings → Environments → production → Edit → Remove required reviewers
# ⚠️ Re-enable after rollback completes!
```

### Step 5: Verify Rollback

```powershell
# Check service health
curl https://api.btg.com/actuator/health

# Check error rate in CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/btg-prod-alb/abc123 \
  --start-time $(Get-Date).AddMinutes(-10).ToString("yyyy-MM-ddTHH:mm:ss") \
  --end-time $(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") \
  --period 60 \
  --statistics Sum

# Should see error count drop after rollback
```

---

## Rollback by Service Type

### Backend Services (ECS)

**What Happens:**
1. ECS registers old task definition
2. ECS updates service to use old task definition
3. ECS starts new tasks with old image
4. ECS drains old tasks (30s grace period)
5. Health checks pass on new (old) tasks
6. ECS terminates drained tasks

**Timeline:** 2-5 minutes (depending on service startup time)

**Monitoring:**
```powershell
# Watch task transitions
aws ecs describe-services \
  --cluster btg-prod-cluster \
  --services auth-server \
  --query 'services[0].events[0:10]' \
  --output table

# Expected events:
# "has started 2 tasks"
# "has reached a steady state"
```

### Frontend Services (MFE)

**What Happens:**
1. DevOps workflow downloads old artifact from GitHub Artifacts
2. Extracts old build files
3. Deploys to S3 (overwrites current files)
4. Invalidates CloudFront cache
5. Users get old version within 1-2 minutes

**Timeline:** 3-5 minutes (CloudFront invalidation)

**Monitoring:**
```powershell
# Check S3 deployment timestamp
aws s3 ls s3://btg-prod-blue/index.html

# Check CloudFront invalidation
aws cloudfront get-invalidation \
  --distribution-id EABCDEF123456 \
  --id <invalidation-id>

# Status should be "Completed"
```

**Caveat:** GitHub Artifacts have 90-day retention. Cannot rollback to versions older than 90 days.

---

## Rollback Validation

### Automated Validation

```powershell
# Run post-rollback validation
.\tools\health-checks\validate-deployment.ps1 -Service auth-server -Environment production

# Expected output:
# ✅ Service health: UP
# ✅ Error rate: <1%
# ✅ Response time p95: <500ms
# ✅ Database connection: OK
```

### Manual Validation Checklist

- [ ] **Service health endpoint returns 200 OK**
- [ ] **Error rate returned to baseline (<1%)**
- [ ] **Response times within SLA (p95 <500ms)**
- [ ] **No exceptions in CloudWatch logs (last 5 minutes)**
- [ ] **User-facing features work (spot check)**
- [ ] **Dependent services still healthy**
- [ ] **No increase in support tickets**

---

## Post-Rollback Actions

### Immediate (Within 1 Hour)

1. **Notify Stakeholders**
```
#incidents Slack channel:
✅ **Rollback Complete**
- Service: auth-server
- Rolled back to: v1.1.0 (xyz789)
- Reason: High error rate (8%) after v1.2.0 deployment
- Status: Service HEALTHY
- Next steps: Root cause analysis in progress
```

2. **Create Incident Report**
```powershell
# Open incident in GitHub Issues
gh issue create \
  --title "Production Rollback: auth-server v1.2.0 → v1.1.0" \
  --body "See template: .github/ISSUE_TEMPLATE/incident-report.md" \
  --label "incident,production,rollback"
```

3. **Preserve Logs**
```powershell
# Export CloudWatch logs from failed deployment
aws logs create-export-task \
  --log-group-name /ecs/auth-server \
  --from $(Get-Date).AddHours(-2).Ticks/10000 \
  --to $(Get-Date).Ticks/10000 \
  --destination s3://btg-incident-logs \
  --destination-prefix "auth-server-rollback-20260113"

# Logs retained for 90 days for analysis
```

### Short-Term (Within 24 Hours)

4. **Root Cause Analysis**
- Review CloudWatch logs for exceptions
- Check Git commit history for breaking changes
- Reproduce issue in dev/staging environment
- Identify specific commit that caused issue

5. **Create Hotfix (If Needed)**
```powershell
# In app repo
git checkout main
git checkout -b hotfix/fix-critical-bug
# ... make fix ...
git commit -m "hotfix: Fix critical bug causing production rollback"
git push origin hotfix/fix-critical-bug

# Create PR, fast-track review, deploy to dev/staging first
```

### Long-Term (Within 1 Week)

6. **Post-Incident Review (PIR)**
- Schedule PIR meeting with team
- Document what went wrong
- Identify prevention measures
- Update monitoring/alerting if issue wasn't caught
- Update testing strategy to catch similar issues

7. **Update Runbooks**
- Document new failure mode in troubleshooting guide
- Add detection method to pre-deployment checklist
- Update rollback decision tree if needed

---

## Advanced Rollback Scenarios

### Scenario 1: Database Migration Incompatibility

**Problem:** New version applied forward-only migration, old version can't read new schema

**Solution:**
```powershell
# DO NOT rollback application yet!

# Step 1: Check if migration is reversible
psql -h prod-db.example.com -U admin -d btg_auth -c "\d+ users"

# Step 2: If migration added column with NOT NULL constraint:
#   - Remove constraint first
#   - Then rollback application
#   - Then rollback migration

# Step 3: Rollback migration (if possible)
cd c:\Git\btg-auth-server
.\scripts\rollback-migration.sh --environment prod --steps 1

# Step 4: Rollback application
cd c:\Git\btg-devops
gh workflow run gateway-service-deployment.yml \
  -f environment=prod
```

**Prevention:** Always make migrations backward-compatible (add nullable columns first, make NOT NULL in later release)

### Scenario 2: Secrets Rotation During Deployment

**Problem:** Deployment failed mid-rotation, half the tasks have old secret, half have new

**Solution:**
```powershell
# Step 1: Keep both secrets active (AWSCURRENT and AWSPREVIOUS)
aws secretsmanager describe-secret \
  --secret-id btg/prod/auth-server/mongodb-uri

# Verify AWSPREVIOUS exists

# Step 2: Rollback application (tasks will use AWSCURRENT)
gh workflow run gateway-service-deployment.yml \
  -f environment=production

# Step 3: After rollback stabilizes, rotate back to old secret
aws secretsmanager update-secret-version-stage \
  --secret-id btg/prod/auth-server/mongodb-uri \
  --version-stage AWSCURRENT \
  --move-to-version-id <previous-version-id>
```

### Scenario 3: Cannot Find Previous Stable Version

**Problem:** Last 10 deployments all failed, need to rollback further

**Solution:**
```powershell
# Step 1: Check GHCR for all available tags
gh api /orgs/BTG-C/packages/container/btg-auth-server/versions \
  | jq -r '.[] | {created: .created_at, tags: .metadata.container.tags}'

# Step 2: Find last known good version from incident reports
cd c:\Git\btg-devops
gh issue list --label "production,success" --limit 20

# Step 3: Rollback to that version (may be weeks old)
gh workflow run mfe-promotion-pipeline.yml \
  -f service=gateway \
  -f image_tag=release-v1.0.0-old123-20251215-100000 \
  -f environment=production
```

**Warning:** Large version gaps may have database incompatibilities

### Scenario 4: Rollback Failed

**Problem:** Rollback deployment itself fails (e.g., GHCR down, AWS outage)

**Solution:**
```powershell
# Emergency: Deploy previous version manually via AWS Console

# Step 1: Get previous task definition ARN
aws ecs list-task-definitions \
  --family-prefix auth-server \
  --sort DESC \
  --max-items 10

# Step 2: Find task definition with old image tag
aws ecs describe-task-definition \
  --task-definition auth-server:42 \
  | jq -r '.taskDefinition.containerDefinitions[0].image'

# Step 3: Update service directly
aws ecs update-service \
  --cluster btg-prod-cluster \
  --service auth-server \
  --task-definition auth-server:42 \
  --force-new-deployment

# Step 4: Document manual intervention in incident report
```

---

## Rollback Decision Tree

```
Deployment fails
    │
    ▼
Is service down? ────YES────> ROLLBACK IMMEDIATELY
    │
    NO
    ▼
Error rate >5%? ────YES────> ROLLBACK (high priority)
    │
    NO
    ▼
Response time >2x baseline? ────YES────> ROLLBACK (medium priority)
    │
    NO
    ▼
Feature not working but not breaking? ────YES────> FORWARD-FIX (low priority)
    │
    NO
    ▼
Minor issues? ────YES────> HOTFIX or wait for next release
    │
    NO
    ▼
Everything working? ────YES────> MONITOR for 30 minutes, then mark success
```

---

## Rollback Testing

### Test Rollback in Staging (Monthly)

**Purpose:** Ensure rollback process works and team is familiar

```powershell
# 1. Deploy current version to staging
gh workflow run gateway-service-deployment.yml \
  -f environment=staging

# 2. Wait for deployment to complete

# 3. Simulate rollback (update GitHub Environment with old image tag first)
gh workflow run gateway-service-deployment.yml \
  -f environment=staging

# 4. Verify rollback succeeded
.\tools\health-checks\validate-deployment.ps1 -Service auth-server -Environment staging

# 5. Document any issues in rollback-test.md
```

**Schedule:** First Monday of each month, 2pm ET

---

## Rollback Metrics (Track in Incident Reports)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Time to Decision** | <5 min | From alert to rollback trigger |
| **Time to Rollback** | <10 min | From trigger to service healthy |
| **Rollback Success Rate** | >95% | Rollbacks that restored service |
| **False Rollbacks** | <5% | Rollbacks that weren't needed |

---

## References

- [Deployment Runbook](DEPLOYMENT-RUNBOOK.md)
- [GitHub Environments Setup](../development/GITHUB-ENVIRONMENTS-SETUP.md)
- [Configuration Flow](../development/CONFIGURATION-FLOW.md)

---

**Last Updated:** 2026-01-13  
**Review Cycle:** Monthly  
**Document Owner:** DevOps Lead
