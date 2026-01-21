# GitHub Actions Workflow Templates

## Overview

This directory contains **TEMPLATES** for GitHub Actions workflows that should be **COPIED** to individual application repositories (MFE repos, backend service repos).

**IMPORTANT:** These templates do NOT run in the btg-devops repository. They are reference templates for setting up CI/CD in app repos.

---

## Why Templates are Here (Not Workflows)

### 2026 DevOps Pattern: Separation of Concerns

```
┌─────────────────────────────────────────────────────────────┐
│ Application Repos (btg-shell-mfe, btg-enhancer-mfe)        │
│                                                             │
│ .github/workflows/                                          │
│   └── artifact-pipeline.yml  ← ACTUAL workflow runs here   │
│                                                             │
│ Job 1: Build & Publish to GHCR                             │
│   - npm run build                                           │
│   - docker build & push to ghcr.io/btg-c/btg-shell-mfe    │
│                                                             │
│ Job 2: Trigger Deployment (repository_dispatch)            │
│   - Notify btg-devops repo: "new artifact ready"          │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ repository_dispatch event
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ DevOps Repo (btg-devops)                                    │
│                                                             │
│ .github/workflows/                                          │
│   └── mfe-promotion-pipeline.yml  ← Deployment workflow    │
│                                                             │
│ Triggered by: repository_dispatch from app repos           │
│ Actions:                                                    │
│   - Pull artifact from GHCR                                │
│   - Deploy to S3 (dev/staging/prod)                        │
│   - Invalidate CloudFront cache                            │
│   - Run smoke tests                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Why This Separation?

### ❌ Wrong Approach: Workflows in DevOps Repo
- App repos build AND deploy (tightly coupled)
- DevOps repo has no control over deployment gates
- Can't promote same artifact across environments

### ✅ Correct Approach: Immutable Artifact Pattern
1. **App repos**: Build once, publish to GHCR
2. **DevOps repo**: Deploy many times (dev → staging → prod)
3. **Same artifact**: Deployed everywhere (immutable)

---

## Available Templates

### 1. `mfe-artifact-pipeline.yml` - Build & Publish Only

**Use For:** btg-shell-mfe, btg-enhancer-mfe (copy to app repos)

**Purpose:** Build immutable artifact and publish to GHCR

**Triggers:**
- Push to `develop` → Build + trigger dev deployment
- Push to `release/*` → Build + trigger staging deployment
- Push to `main` → Build + trigger prod deployment

**Jobs:**
1. **build-publish**: Build Angular app, publish to GHCR
2. **trigger-deployment**: Send repository_dispatch to btg-devops

**Does NOT deploy to AWS** - deployment happens in btg-devops repo

**Copy to app repo:**
```powershell
# Copy template to btg-shell-mfe
Copy-Item `
  -Path "c:\Git\btg-devops\.github\workflow-templates\mfe-artifact-pipeline.yml" `
  -Destination "c:\Git\btg-shell-mfe\.github\workflows\artifact-pipeline.yml"

# Update APP_NAME in the workflow
# Change: APP_NAME: shell
```

---

### 2. `backend-ci-cd.yml` - Backend Service Template (Future)

**Use For:** btg-auth-server, btg-gateway-service

**Jobs:**
1. Build Spring Boot JAR
2. Build Docker image
3. Push to GHCR
4. Trigger ECS deployment via DevOps repo

---

## DevOps Repo Workflows (Actual Workflows - Already Created)

The btg-devops repo HAS actual workflows that run deployments:

```
btg-devops/
└── .github/workflows/                    ← Actual workflows run here
    ├── mfe-promotion-pipeline.yml        ← ✅ Deploys MFEs to AWS
    ├── terraform-plan.yml (future)       ← Terraform PR validation
    └── terraform-apply.yml (future)      ← Infrastructure deployment
```

These workflows:
- **mfe-promotion-pipeline.yml**: ✅ **ACTIVE** - Triggered by `repository_dispatch` from app repos, pulls from GHCR, deploys to S3+CloudFront
- **terraform-plan.yml**: (Future) Runs on PR to validate infrastructure changes
- **terraform-apply.yml**: (Future) Deploys infrastructure on merge to main

---

## Setup Guide

### Step 1: Copy Template to App Repo

```powershell
# For Shell MFE
cd c:\Git\btg-shell-mfe
New-Item -ItemType Directory -Force -Path ".github\workflows"
Copy-Item `
  -Path "c:\Git\btg-devops\.github\workflow-templates\mfe-ci-cd.yml" `
  -Destination ".github\workflows\ci-cd.yml"
```

### Step 2: Customize for Your App

Edit `.github/workflows/ci-cd.yml`:

```yaml
env:
  APP_NAME: shell           # Change to: enhancer, analytics, etc.
  NODE_VERSION: '20'
  REGISTRY: ghcr.io
```

### Step 3: Configure GitHub Secrets

In app repo settings (btg-shell-mfe):
- `AWS_REGION`: us-east-1
- `AWS_ROLE_ARN`: (from Terraform output)
- `S3_BUCKET_NAME`: (from Terraform output)
- `CLOUDFRONT_DISTRIBUTION_ID`: (from Terraform output)

### Step 4: Test Deployment

```powershell
# Push to develop branch
git checkout develop
git push origin develop

# Watch GitHub Actions: https://github.com/BTG-C/btg-shell-mfe/actions
```

---

## Template vs Workflow Comparison

| Location | Type | Purpose | Runs When? |
|----------|------|---------|------------|
| `btg-devops/.github/workflow-templates/` | **Template** | Reference for app repos | Never (copy only) |
| `btg-shell-mfe/.github/workflows/` | **Actual Workflow** | Build & publish shell MFE | On push to branches |
| `btg-devops/.github/workflows/` | **Actual Workflow** | Deploy to AWS | On repository_dispatch |

---

## 2026 Best Practice: Why No Workflows in DevOps Repo (Yet)

**Current State (Phase 1):**
- App repos build + deploy directly to AWS (simplified)
- Templates provided for consistency

**Future State (Phase 2 - After Migration):**
- App repos: Build + publish to GHCR only
- DevOps repo: Receives `repository_dispatch`, deploys to AWS
- Better separation of concerns

**We'll add `promotion-pipeline.yml` to btg-devops/.github/workflows/ once app repos are migrated to this pattern.**

---

## Questions?

- **Q: Why not put workflows in DevOps repo now?**
  - A: App repos need workflows first to build artifacts. DevOps repo workflows come later for deployment orchestration.

- **Q: Can I modify the template?**
  - A: Yes! Templates are starting points. Customize for your app's needs.

- **Q: Do I need to sync changes back to the template?**
  - A: If you improve the workflow, consider updating the template so other apps benefit.

---

## Related Documentation

- [Deployment Runbook](../../docs/operations/DEPLOYMENT-RUNBOOK.md)
- [Quick Start Guide](../../docs/development/QUICK-START.md)
- [AWS Organization Setup](../../docs/infrastructure/AWS-ORGANIZATION-SETUP.md)
- [BTG Deployment](../../docs/infrastructure/BTG-AWS-DEPLOYMENT.md)
