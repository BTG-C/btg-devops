# GitHub Environments Setup Guide

## Overview

GitHub Environments provide deployment protection rules, secrets management, and approval gates for production deployments. This guide shows how to configure environments for the BTG DevOps repository.

**Important:** Environments are configured in the **btg-devops** repository (not app repos) because deployments happen here.

---

## Why GitHub Environments?

### 2026 Best Practice: Environment-Based Access Control

```
┌─────────────────────────────────────────────────────────────┐
│ GitHub Environments in btg-devops Repository                │
│                                                             │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│ │    dev      │  │  staging    │  │    prod     │        │
│ │             │  │             │  │             │        │
│ │ No approval │  │ No approval │  │ 2 reviewers │        │
│ │ Auto-deploy │  │ Auto-deploy │  │ 5 min wait  │        │
│ └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│ Each environment has:                                       │
│ • AWS credentials (secrets)                                 │
│ • Deployment protection rules                               │
│ • Required reviewers                                        │
│ • Branch restrictions                                       │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ Production deployments require approval
- ✅ Secrets isolated per environment
- ✅ Audit trail of who approved what
- ✅ Can restrict deployments to specific branches

---

## Step-by-Step Setup

### Prerequisites

✅ You must be a **repository admin** to configure environments  
✅ Repository must be **private** or on **GitHub Team/Enterprise** plan  
✅ Terraform infrastructure must be deployed (to get AWS role ARNs)

---

## Step 1: Create Environments

### Navigate to Repository Settings

1. Go to: https://github.com/BTG-C/btg-devops
2. Click **Settings** tab
3. Click **Environments** (left sidebar)
4. Click **New environment**

### Create Three Environments

Create the following environments in order:

1. **dev** (development)
2. **staging** (pre-production)
3. **production** (live)

---

## Step 2: Configure Dev Environment

### Environment: `dev`

**Purpose:** Automatic deployments for development testing

**Configuration:**

1. Click **New environment** → Enter name: `dev`
2. Click **Configure environment**

#### Protection Rules
- ❌ **Required reviewers**: None (auto-deploy)
- ❌ **Wait timer**: None
- ✅ **Deployment branches**: Selected branches only
  - Add branch: `main` (or `master`)

#### Environment Secrets

Click **Add secret** for each:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for dev account |
| `AWS_ROLE_ARN` | `arn:aws:iam::111111111111:role/btg-dev-github-actions-role` | From Terraform output (dev account) |
| `S3_BUCKET_NAME` | `btg-dev-blue` | From Terraform output |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E1ABC2DEF3GHI` | From Terraform output |
| `CLOUDFRONT_URL` | `https://d1abc2def3ghi.cloudfront.net` | From Terraform output |

**Get values from Terraform:**
```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-dev
terraform output
```

3. Click **Save protection rules**

---

## Step 3: Configure Staging Environment

### Environment: `staging`

**Purpose:** Pre-production testing before prod deployment

**Configuration:**

1. Click **New environment** → Enter name: `staging`
2. Click **Configure environment**

#### Protection Rules
- ❌ **Required reviewers**: None (auto-deploy from release branches)
- ❌ **Wait timer**: None
- ✅ **Deployment branches**: Selected branches only
  - Add branch: `main`
  - Add pattern: `release/*`

#### Environment Secrets

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for prod account |
| `AWS_ROLE_ARN` | `arn:aws:iam::222222222222:role/btg-staging-github-actions-role` | From Terraform output (prod account) |
| `S3_BUCKET_NAME` | `btg-staging-blue` | From Terraform output |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E4DEF5GHI6JKL` | From Terraform output |
| `CLOUDFRONT_URL` | `https://d4def5ghi6jkl.cloudfront.net` | From Terraform output |

**Get values from Terraform:**
```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-staging
terraform output
```

3. Click **Save protection rules**

---

## Step 4: Configure Production Environment (with Approvals)

### Environment: `production`

**Purpose:** Live production deployments with mandatory approvals

**Configuration:**

1. Click **New environment** → Enter name: `production`
2. Click **Configure environment**

#### Protection Rules

##### ✅ Required Reviewers (CRITICAL)

1. Check **Required reviewers**
2. Add reviewers (select at least 2):
   - **DevOps Lead** (e.g., @devops-lead)
   - **Engineering Manager** (e.g., @engineering-manager)
   - **CTO** (e.g., @cto)
3. **Number of required reviewers**: `2` (recommended)

**How it works:**
- Workflow pauses at production deployment
- 2 reviewers from the list must approve
- Approvers receive GitHub notification
- Deployment proceeds only after approval

##### ✅ Wait Timer (Optional but Recommended)

1. Check **Wait timer**
2. Set to: `5` minutes

**Purpose:** Gives team time to:
- Review deployment plan
- Check monitoring dashboards
- Cancel if needed

##### ✅ Deployment Branches

1. Check **Deployment branches**
2. Select: **Selected branches only**
3. Add branch: `main` (only production branch can deploy to prod)

#### Environment Secrets

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for prod account |
| `AWS_ROLE_ARN` | `arn:aws:iam::222222222222:role/btg-prod-github-actions-role` | From Terraform output (prod account) |
| `S3_BUCKET_NAME` | `btg-prod-blue` | From Terraform output |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E7GHI8JKL9MNO` | From Terraform output |
| `CLOUDFRONT_URL` | `https://d7ghi8jkl9mno.cloudfront.net` or `https://app.btg.com` | From Terraform output or custom domain |

**Get values from Terraform:**
```powershell
cd c:\Git\btg-devops\infrastructure\terraform\env-prod
terraform output
```

3. Click **Save protection rules**

---

## Step 5: Verify Configuration

### Check Environment Summary

Navigate to: https://github.com/BTG-C/btg-devops/settings/environments

You should see:

```
┌────────────────────────────────────────────────────────────┐
│ Environments                                                │
├────────────────────────────────────────────────────────────┤
│ dev          No protection rules                           │
│ staging      No protection rules                           │
│ production   2 required reviewers, 5 min wait             │
└────────────────────────────────────────────────────────────┘
```

---

## How Approvals Work

### Production Deployment Flow

```
1. Developer pushes code to main branch
   ↓
2. App repo builds artifact, pushes to GHCR
   ↓
3. App repo sends repository_dispatch to btg-devops
   ↓
4. btg-devops workflow starts
   ↓
5. deploy-dev job runs (auto, no approval)
   ✅ Deployed to dev
   ↓
6. deploy-staging job runs (auto, no approval)
   ✅ Deployed to staging
   ↓
7. deploy-prod job PAUSES ⏸️
   
   GitHub UI shows:
   ┌──────────────────────────────────────────────┐
   │ 🟡 Waiting for approval                      │
   │                                              │
   │ Required reviewers: 2 of 3                   │
   │ • @devops-lead                               │
   │ • @engineering-manager                       │
   │ • @cto                                       │
   │                                              │
   │ [Review deployment]                          │
   └──────────────────────────────────────────────┘
   ↓
8. Reviewers click "Review deployment"
   - Check logs, metrics, staging tests
   - Approve or Reject
   ↓
9. After 2 approvals + 5 min wait
   ✅ deploy-prod job runs
   ✅ Deployed to production
```

### Approval Notifications

Reviewers receive notifications via:
- 📧 Email: "Deployment requires your approval"
- 🔔 GitHub notifications
- 💬 Slack (if configured with GitHub Actions)

---

## Step 6: Test Approval Flow

### Trigger a Production Deployment

1. **Manually trigger deployment:**
   - Go to: https://github.com/BTG-C/btg-devops/actions
   - Click **MFE Promotion Pipeline**
   - Click **Run workflow**
   - Select:
     - `app_name`: shell
     - `build_version`: (use any GHCR version)
     - `environment`: prod
     - `action`: deploy
   - Click **Run workflow**

2. **Wait for approval gate:**
   - Navigate to workflow run
   - See status: "⏸️ Waiting for approval"
   - Check "Review pending deployments"

3. **Approve deployment (as reviewer):**
   - Click **Review pending deployments**
   - Review deployment details
   - Check **production** checkbox
   - Select: **Approve and deploy**
   - Click **Approve deployment**

4. **Second reviewer approves:**
   - Repeat steps for second reviewer
   - After 2nd approval, deployment proceeds

5. **Wait timer:**
   - 5-minute countdown starts
   - Can cancel during this window if needed

6. **Deployment completes:**
   - deploy-prod job runs
   - Artifact deployed to S3
   - CloudFront invalidated
   - ✅ Production updated

---

## Managing Reviewers

### Add/Remove Reviewers

1. Go to: https://github.com/BTG-C/btg-devops/settings/environments
2. Click **production**
3. Under **Required reviewers**:
   - **Add**: Click search box, select user
   - **Remove**: Click ❌ next to user
4. Click **Save protection rules**

### Who Should Be a Reviewer?

**Recommended reviewers:**
- ✅ DevOps Lead (primary approver)
- ✅ Engineering Manager (business approval)
- ✅ CTO or VP Engineering (executive oversight)
- ✅ On-call engineer (technical validation)

**Avoid:**
- ❌ Individual developers (shouldn't approve their own deployments)
- ❌ External contractors (security risk)

---

## Advanced Configuration

### Restrict Deployment to Specific Times

**Use Case:** Only allow production deployments during business hours

1. Use **Deployment protection rules** API
2. Create custom GitHub App or Action
3. Check current time, reject if outside window

**Example (future feature):**
```yaml
# In .github/workflows/mfe-promotion-pipeline.yml
- name: Check deployment window
  run: |
    HOUR=$(date +%H)
    DAY=$(date +%u)
    if [ $DAY -gt 5 ] || [ $HOUR -lt 9 ] || [ $HOUR -gt 17 ]; then
      echo "❌ Production deployments only allowed Mon-Fri 9am-5pm EST"
      exit 1
    fi
```

### Environment Variables (Non-Secret)

For non-sensitive configuration:

1. Go to environment settings
2. Click **Add variable**
3. Examples:
   - `LOG_LEVEL`: `info`
   - `FEATURE_FLAGS`: `new-ui=true,beta-api=false`
   - `MAX_CACHE_AGE`: `86400`

---

## Troubleshooting

### Issue: "Environment not found"

**Cause:** Workflow references wrong environment name

**Fix:**
```yaml
# In .github/workflows/mfe-promotion-pipeline.yml
deploy-prod:
  environment: production    # Must match exact name in GitHub
```

### Issue: "Secret not found"

**Cause:** Secret not configured for environment

**Fix:**
1. Go to: https://github.com/BTG-C/btg-devops/settings/environments
2. Click environment name
3. Add missing secret under **Environment secrets**

### Issue: "No reviewers available"

**Cause:** All reviewers are unavailable or not org members

**Fix:**
1. Add more reviewers to the list
2. Or temporarily reduce required reviewers from 2 to 1

### Issue: "Deployment stuck on approval"

**Cause:** Reviewers not responding

**Fix:**
1. Notify reviewers via Slack/email
2. Or cancel deployment and re-trigger later
3. Consider adding more reviewers to the list

---

## Security Best Practices

### ✅ Do's

- ✅ Use OIDC for AWS credentials (no static keys)
- ✅ Require 2+ reviewers for production
- ✅ Use wait timer to allow cancellation
- ✅ Restrict production to `main` branch only
- ✅ Rotate secrets quarterly
- ✅ Audit deployment logs monthly

### ❌ Don'ts

- ❌ Don't share secret values in Slack/email
- ❌ Don't let developers approve their own deployments
- ❌ Don't skip approvals "just this once"
- ❌ Don't use same AWS credentials across environments
- ❌ Don't commit secrets to Git (use GitHub Secrets only)

---

## Cost

**GitHub Environments pricing:**
- **Free**: For public repositories
- **Included**: GitHub Team ($4/user/month)
- **Included**: GitHub Enterprise ($21/user/month)

**For private repositories on Free plan:**
- Environments are NOT available
- Upgrade to Team or Enterprise

---

## Summary

✅ **Environments configured:**
- `dev`: Auto-deploy, no approval
- `staging`: Auto-deploy, no approval
- `production`: 2 reviewers + 5 min wait

✅ **Secrets configured per environment:**
- AWS_REGION
- AWS_ROLE_ARN
- S3_BUCKET_NAME
- CLOUDFRONT_DISTRIBUTION_ID
- CLOUDFRONT_URL

✅ **Protection rules:**
- Production requires 2 approvals
- Only `main` branch can deploy to prod
- 5-minute wait timer for emergency cancellation

✅ **Audit trail:**
- GitHub records who approved each deployment
- Visible in Actions logs and audit log

---

## Next Steps

1. ✅ Create GitHub Environments (this guide)
2. ⏭️ Copy workflow template to app repos
3. ⏭️ Test dev deployment (auto)
4. ⏭️ Test staging deployment (auto)
5. ⏭️ Test production deployment (with approval)
6. ⏭️ Train team on approval process

See: [Deployment Runbook](../operations/DEPLOYMENT-RUNBOOK.md)
