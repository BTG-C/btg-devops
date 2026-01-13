# BTG DevOps Repository - Setup Complete ✅

**Created:** 2026-01-13  
**Purpose:** Centralized deployment orchestration following 2026 Future-Proof Multi-Repo Immutable Pipeline architecture

---

## What Was Created

### 📁 **Repository Structure**

```
btg-devops/
├── README.md                         # Main repository documentation
├── .github/workflows/                # GitHub Actions workflows (to be added)
├── docs/                             # Organized documentation
│   ├── architecture/
│   │   └── OVERVIEW.md              # ✅ System architecture & design decisions
│   ├── development/
│   │   └── QUICK-START.md           # ✅ 10-minute getting started guide
│   ├── operations/
│   │   ├── DEPLOYMENT-RUNBOOK.md    # ✅ Step-by-step deployment guide
│   │   └── ROLLBACK-PROCEDURES.md   # ✅ Emergency rollback procedures
│   ├── security/                     # (To be populated)
│   └── troubleshooting/              # (To be populated)
├── services/                         # Service-specific configs
│   ├── auth-server/
│   │   ├── README.md                # ✅ Auth server deployment config
│   │   ├── ecs/                     # ECS task definitions (to be added)
│   │   └── config/                  # GitHub Environment configs (to be added)
│   ├── gateway-service/
│   ├── shell-mfe/
│   │   ├── README.md                # ✅ Shell MFE deployment config
│   │   ├── s3/                      # S3 deployment configs (to be added)
│   │   └── cloudfront/              # CloudFront configs (to be added)
│   └── enhancer-mfe/
├── infrastructure/                   # Terraform IaC
│   ├── terraform/
│   │   ├── global/                  # Shared VPC, ECS clusters (to be migrated)
│   │   ├── env-dev/
│   │   ├── env-staging/
│   │   └── env-prod/
│   └── scripts/                     # Helper scripts (to be added)
└── tools/                           # Utilities
    ├── health-checks/               # Validation scripts (to be added)
    └── migrations/                  # Data migration tools (to be added)
```

---

## ✅ Completed Tasks

### Core Documentation Created

1. **README.md** - Main repository overview with:
   - Purpose and principles
   - Directory structure
   - Documentation index
   - Quick links
   - Service catalog
   - GitHub Environments setup
   - Common tasks
   - Emergency contacts

2. **docs/development/QUICK-START.md** - Getting started guide with:
   - Prerequisites installation (Windows/macOS)
   - Authentication setup (GitHub CLI + AWS CLI)
   - Repository cloning
   - Setup verification script
   - First deployment walkthrough
   - Troubleshooting common issues

3. **docs/architecture/OVERVIEW.md** - Architecture documentation with:
   - High-level system diagram
   - Core principles (immutability, separation of concerns)
   - Repository strategy justification
   - Deployment flow sequence diagram
   - Technology stack decisions
   - Security model (defense in depth)
   - Scalability projections

4. **docs/operations/DEPLOYMENT-RUNBOOK.md** - Operational guide with:
   - Pre-deployment checklist
   - Deploy to dev/staging/production procedures
   - Post-deployment validation
   - Monitoring dashboards
   - Troubleshooting common issues
   - Emergency procedures
   - Deployment schedule and blackout periods

5. **docs/operations/ROLLBACK-PROCEDURES.md** - Emergency response with:
   - Rollback decision criteria
   - 5-minute quick rollback procedure
   - Service-specific rollback steps
   - Post-rollback validation
   - Advanced scenarios (DB migrations, secret rotation)
   - Rollback decision tree
   - Rollback testing procedures

6. **services/auth-server/README.md** - Service-specific deployment with:
   - Service overview
   - Directory structure
   - GitHub Environment variables per environment
   - ECS task definition blueprint explanation
   - Deployment process
   - Health checks
   - Monitoring and troubleshooting

7. **services/shell-mfe/README.md** - Frontend deployment with:
   - S3 + CloudFront setup
   - Cache strategy
   - Runtime configuration injection
   - Module Federation integration
   - Performance optimization
   - Troubleshooting

---

## 📋 Next Steps (Implementation Roadmap)

### Phase 1: GitHub Setup (Week 1)

- [ ] Initialize Git repository
```powershell
cd c:\Git\btg-devops
git init
git add .
git commit -m "Initial commit: DevOps repository structure"
git branch -M main
```

- [ ] Create GitHub repository
```powershell
gh repo create BTG-C/btg-devops --private --source=. --remote=origin --push
```

- [ ] Configure GitHub Environments
```powershell
# Create environments via GitHub UI or CLI
gh api repos/BTG-C/btg-devops/environments/dev -X PUT
gh api repos/BTG-C/btg-devops/environments/staging -X PUT
gh api repos/BTG-C/btg-devops/environments/production -X PUT
```

- [ ] Set environment variables (see service READMEs for values)

- [ ] Configure protection rules for `production` environment:
  - Required reviewers: 2
  - Wait timer: 5 minutes
  - Deployment branches: `main` only

### Phase 2: Workflow Creation (Week 2)

- [ ] Create `.github/workflows/promotion-pipeline.yml`
- [ ] Create `.github/workflows/rollback-pipeline.yml`
- [ ] Create `.github/workflows/terraform-apply.yml`
- [ ] Test workflows in dev environment

### Phase 3: Service Configuration (Week 3-4)

- [ ] Migrate `auth-server` configurations:
  - Create `services/auth-server/ecs/service-blueprint.json`
  - Create environment-specific configs
  - Test deployment to dev

- [ ] Migrate `gateway-service` configurations

- [ ] Migrate `shell-mfe` configurations:
  - Create `services/shell-mfe/s3/deploy-config.yaml`
  - Create `services/shell-mfe/cloudfront/invalidation-paths.txt`
  - Test deployment to dev

- [ ] Migrate `enhancer-mfe` configurations

### Phase 4: Infrastructure Migration (Week 5-6)

- [ ] Move Terraform from `btg-deployment-scripts` to `btg-devops/infrastructure/terraform/`
- [ ] Organize by environment (global, dev, staging, prod)
- [ ] Test infrastructure changes in dev
- [ ] Migrate secrets to AWS Secrets Manager (if not already done)

### Phase 5: Additional Documentation (Week 7-8)

- [ ] Create `docs/security/SECRETS-MANAGEMENT.md`
- [ ] Create `docs/security/IAM-POLICIES.md`
- [ ] Create `docs/security/COMPLIANCE.md`
- [ ] Create `docs/troubleshooting/COMMON-ISSUES.md`
- [ ] Create `docs/troubleshooting/DEBUG-WORKFLOWS.md`
- [ ] Create `docs/development/DEVELOPER-WORKFLOW.md`
- [ ] Create `docs/development/ADD-NEW-SERVICE.md`
- [ ] Create `docs/operations/DISASTER-RECOVERY.md`
- [ ] Create `docs/operations/MONITORING.md`

### Phase 6: Tools & Scripts (Week 9-10)

- [ ] Create `tools/setup-github-environments.ps1`
- [ ] Create `tools/health-checks/validate-deployment.ps1`
- [ ] Create `tools/health-checks/run-smoke-tests.ps1`
- [ ] Create `infrastructure/scripts/rotate-secrets.sh`
- [ ] Create `infrastructure/scripts/backup-secrets.sh`

### Phase 7: Testing & Validation (Week 11-12)

- [ ] Deploy all services to dev using new pipeline
- [ ] Deploy to staging
- [ ] Perform load testing
- [ ] Test rollback procedures
- [ ] Train team on new workflows
- [ ] Document lessons learned

### Phase 8: Production Cutover (Week 13)

- [ ] Schedule production migration window
- [ ] Deploy to production using new pipeline
- [ ] Monitor for 48 hours
- [ ] Archive old `btg-deployment-scripts` repository
- [ ] Update all documentation links

---

## 🎓 Key Concepts to Understand

### 1. Immutable Artifacts
**One image for all environments**
```
ghcr.io/btg-c/auth-server:abc123
  ├─> Deploy to dev (with dev secrets)
  ├─> Deploy to staging (with staging secrets)
  └─> Deploy to prod (with prod secrets)
```

### 2. Separation of Concerns
**App repos build, DevOps repo deploys**
- `btg-auth-server` → Builds Docker image, runs tests
- `btg-devops` → Deploys image to ECS, manages secrets ARNs

### 3. Runtime Configuration Hydration
**No hardcoded values in images**
```dockerfile
# Containerfile includes template
COPY application.template.yaml config/

# Runtime script substitutes variables
ENTRYPOINT ["runtime-init.sh"]  # Runs envsubst on template
```

### 4. GitHub Environments
**Per-environment config + approvals**
```
dev:       No approvals, dev secret ARNs
staging:   No approvals, staging secret ARNs
production: 2 approvals + 5 min wait, prod secret ARNs
```

---

## 📚 Documentation Reading Order

For new team members:

1. **README.md** (this repo's main README) - Get overview
2. **docs/development/QUICK-START.md** - Set up your machine
3. **docs/architecture/OVERVIEW.md** - Understand the system
4. **docs/operations/DEPLOYMENT-RUNBOOK.md** - Learn deployment process
5. **docs/operations/ROLLBACK-PROCEDURES.md** - Learn emergency response
6. **services/{service-name}/README.md** - Understand specific services

---

## 🔗 Important Links

### GitHub
- **btg-devops repo:** https://github.com/BTG-C/btg-devops
- **GitHub Actions:** https://github.com/BTG-C/btg-devops/actions
- **GitHub Environments:** https://github.com/BTG-C/btg-devops/settings/environments

### AWS
- **ECS Clusters:** https://console.aws.amazon.com/ecs/v2/clusters
- **Secrets Manager:** https://console.aws.amazon.com/secretsmanager/home
- **CloudWatch Dashboards:** https://console.aws.amazon.com/cloudwatch/home#dashboards
- **S3 Buckets:** https://s3.console.aws.amazon.com/s3/buckets
- **CloudFront:** https://console.aws.amazon.com/cloudfront/v3/home

### Communication
- **Slack:** #btg-devops
- **Incident Channel:** #btg-incidents
- **Releases Channel:** #releases

---

## ⚠️ Migration from btg-deployment-scripts

**Status:** In progress

### What to Keep
- ✅ Terraform modules (move to `infrastructure/terraform/`)
- ✅ Workflow templates (adapt for new structure)
- ✅ Scripts (move to `infrastructure/scripts/` or `tools/`)
- ✅ Documentation (consolidate into domain-specific docs)

### What to Delete
- ❌ Old workflow files (replaced by promotion-pipeline.yml)
- ❌ Hardcoded configs (replaced by GitHub Environments)
- ❌ Single-doc architecture files (split into multiple domain docs)

### Timeline
- **Week 1-6:** Parallel operation (both repos active)
- **Week 7-12:** Gradual migration service-by-service
- **Week 13:** Full cutover to btg-devops
- **Week 14:** Archive btg-deployment-scripts (read-only)

---

## 🎯 Success Criteria

Repository is fully operational when:

- [ ] All 7 services (4 backend, 3 frontend) deployable via promotion-pipeline
- [ ] GitHub Environments configured for all 3 environments
- [ ] All secrets migrated to AWS Secrets Manager
- [ ] Terraform infrastructure migrated and tested
- [ ] Team trained on new workflows
- [ ] All documentation complete
- [ ] Rollback tested successfully in staging
- [ ] Production deployment successful with zero downtime
- [ ] btg-deployment-scripts repository archived

---

## 🆘 Getting Help

- **Setup Issues:** See docs/development/QUICK-START.md
- **Deployment Issues:** See docs/operations/DEPLOYMENT-RUNBOOK.md
- **Architecture Questions:** See docs/architecture/OVERVIEW.md
- **Emergency:** See docs/operations/ROLLBACK-PROCEDURES.md
- **General:** Slack #btg-devops or email devops@btg.com

---

**Repository Status:** 🟡 Initial Setup Complete - Ready for Phase 1  
**Next Action:** Initialize Git repository and create on GitHub  
**Estimated Time to Full Production:** 13 weeks  
**Team:** DevOps (2), Backend (3), Frontend (2)

---

**Questions?** Contact DevOps Lead in Slack: @devops-lead
