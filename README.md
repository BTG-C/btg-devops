# BTG DevOps Repository

**Centralized deployment orchestration, infrastructure as code, and operational documentation for all BTG services.**

---

## 🎯 Purpose

This repository implements the **2026 Future-Proof Multi-Repo Immutable Pipeline** architecture, separating deployment orchestration from application code.

### Key Principles
- **Immutable Artifacts:** Build once in app repos (GHCR), deploy many times from here
- **Environment Governance:** All env-specific configs and approvals managed centrally via GitHub Environments
- **Zero Hardcoding:** Runtime secrets via AWS Secrets Manager (ECS task role injection)
- **Audit Trail:** All deployments tracked through GitHub Actions runs

---

## 📁 Repository Structure

```
btg-devops/
├── .github/
│   ├── workflows/                    # ACTUAL deployment workflows (run in btg-devops)
│   │   ├── gateway-service-deployment.yml
│   │   └── mfe-promotion-pipeline.yml
│   └── workflow-templates/           # Templates to copy to app repos
│       ├── mfe-artifact-pipeline.yml
│       └── README.md
│
├── services/                         # Service-specific deployment configs
│   ├── gateway-service/
│   │   └── README.md                # Documentation only
│   ├── shell-mfe/
│   │   └── README.md                # Documentation only
│   └── auth-server/
│       └── README.md                # Documentation only
│   # Note: ECS task/service configs managed by Terraform modules
│
├── docs/                            # Documentation organized by domain
│   └── terraform/
│       ├── README.md                 # Multi-account structure docs
│       ├── modules/
│       │   ├── mfe-s3/              # S3 bucket for MFE hosting
│       │   ├── mfe-cloudfront/     # CloudFront CDN distribution
│       │   └── mfe-iam/            # GitHub Actions IAM roles
│       ├── env-dev/                 # Dev environment (separate AWS account)
│       ├── env-staging/             # Staging (prod AWS account)
│       ├── env-prod/                # Production (prod AWS account)
│       └── infra-setup-pre-terraform/           # One-time S3+DynamoDB setup
│           ├── dev/
│           └── prod/
│
├── docs/                            # Documentation organized by domain
│   ├── architecture/
│   │   └── OVERVIEW.md
│   ├── development/
│   │   ├── QUICK-START.md
│   │   ├── GITHUB-ENVIRONMENTS-SETUP.md
│   │   ├── GITHUB-ENVIRONMENTS-GATEWAY.md
│   │   └── CONFIGURATION-FLOW.md
│   ├── infrastructure/
│   │   ├── AWS-ORGANIZATION-SETUP.md
│   │   ├── BTG-AWS-DEPLOYMENT.md
│   │   └── DOCUMENTDB_SETUP.md
│   ├── operations/
│   │   ├── DEPLOYMENT-RUNBOOK.md
│   │   └── ROLLBACK-PROCEDURES.md
│   ├── security/
│   └── troubleshooting/
│
├── tools/                           # Helper scripts (empty for now, YAGNI)
│   ├── health-checks/
│   └── migrations/
│
├── README.md                        # This file
├── SETUP-COMPLETE.md                # Migration roadmap
└── repository-structure.txt         # Generated structure
```

---

## 🚀 Quick Start

### Prerequisites
- Git installed
- GitHub Personal Access Token with `workflow` scope
- AWS CLI v2 installed and configured (for infrastructure setup)
- Terraform 1.6+ installed (for infrastructure setup)

### First-Time Setup
```powershell
# 1. Clone repository
cd c:\Git
git clone https://github.com/BTG-C/btg-devops.git
cd btg-devops

# 2. Configure GitHub Environments (in GitHub UI)
# Go to: Settings → Environments → Create environments (dev, staging, production)
# See: docs/development/GITHUB-ENVIRONMENTS-SETUP.md

# 3. Setup Terraform backend (one-time per AWS account)
cd infrastructure/terraform/infra-setup-pre-terraform/dev
terraform init && terraform apply

cd ../prod
terraform init && terraform apply

# 4. Deploy infrastructure
cd ../../env-dev
terraform init && terraform plan && terraform apply

# 5. Copy workflow templates to app repos
# Copy .github/workflow-templates/mfe-artifact-pipeline.yml to app repo .github/workflows/
# See: .github/workflow-templates/README.md
```

### Deploy Your First Service
```powershell
# Push code to app repo (btg-gateway-service, btg-shell-mfe)
# Artifact pipeline builds Docker image → Publishes to GHCR → Triggers btg-devops

# Or manually trigger deployment:
# Go to: https://github.com/BTG-C/btg-devops/actions
# Select "Gateway Service Deployment" workflow
# Click "Run workflow"
# Choose environment and image tag
```

---

## 📚 Documentation Index

### Getting Started
- [Quick Start Guide](docs/development/QUICK-START.md) - 10-minute setup
- [Architecture Overview](docs/architecture/OVERVIEW.md) - System design
- [Configuration Flow](docs/development/CONFIGURATION-FLOW.md) - GitHub → AWS flow

### Development
- [GitHub Environments Setup](docs/development/GITHUB-ENVIRONMENTS-SETUP.md) - Complete guide for MFE deployments
- [Gateway Service Environments](docs/development/GITHUB-ENVIRONMENTS-GATEWAY.md) - ECS deployment configuration
- [Workflow Templates](. github/workflow-templates/README.md) - Copy to app repos

### Operations
- [Deployment Runbook](docs/operations/DEPLOYMENT-RUNBOOK.md) - Step-by-step deployment
- [Rollback Procedures](docs/operations/ROLLBACK-PROCEDURES.md) - Emergency response

### Infrastructure
- [AWS Organization Setup](docs/infrastructure/AWS-ORGANIZATION-SETUP.md) - Generic multi-account setup
- [BTG AWS Deployment](docs/infrastructure/BTG-AWS-DEPLOYMENT.md) - BTG-specific infrastructure
- [Terraform Structure](infrastructure/terraform/README.md) - Multi-account organization

### Security
- Secrets management via AWS Secrets Manager (ECS runtime injection)
- IAM roles with least privilege (GitHub OIDC)
- No secrets in Git or GitHub (ARN paths only)

---

## 🏗️ Services

### Backend Services (ECS Fargate)
| Service | Description | Health Check | Status |
|---------|-------------|--------------|--------|
| [gateway-service](services/gateway-service/) | API Gateway (Spring Cloud) | `/actuator/health` | ✅ Configured |
| auth-server | OAuth2/OIDC Authorization | `/actuator/health` | 📋 Pending |

### Frontend Services (S3 + CloudFront)
| Service | Description | Path | Status |
|---------|-------------|------|--------|
| [shell-mfe](services/shell-mfe/) | Angular Shell (Host) | `/` | ✅ Configured |
| enhancer-mfe | Angular MFE | `/mfe-bundles/enhancer/` | 📋 Pending |

**Note:** Services marked "Configured" have deployment workflows and configs ready. Services marked "Pending" need configuration files added to `services/` folder.

---

## 🔐 GitHub Environments

Configure in: `Settings → Environments → [environment name]`

### Development (`dev`)
- **Auto-deploy:** Push to `develop` branch in app repos
- **Approvals:** None
- **AWS Account:** Separate dev account
- **Secrets to configure:**
  - `AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_ROLE_ARN`
  - `GATEWAY_CLUSTER`, `GATEWAY_SERVICE`, `GATEWAY_ALB_URL`
  - `SHELL_S3_BUCKET`, `SHELL_CLOUDFRONT_ID`, `SHELL_CLOUDFRONT_URL`

### Staging (`staging`)
- **Auto-deploy:** Push to `release/*` branch in app repos
- **Approvals:** None
- **AWS Account:** Production account (separate state)
- **Secrets:** Same as dev, with staging values

### Production (`production`)
- **Auto-deploy:** None (manual trigger only)
- **Approvals:** 2 reviewers + 5 min wait timer
- **Branch restriction:** `main` only
- **AWS Account:** Production account
- **Secrets:** Same as dev, with production values

See: [GitHub Environments Setup Guide](docs/development/GITHUB-ENVIRONMENTS-SETUP.md)

---

## 🛠️ Common Tasks

### Deploy to Development
```powershell
# Gateway Service: Automatically triggered when btg-gateway-service pushes to 'develop' branch
# MFEs: Automatically triggered when btg-shell-mfe pushes to 'develop' branch
# No manual action needed - workflows trigger via repository_dispatch
```

### Deploy to Staging
```powershell
# Automatically triggered when app repo pushes to 'release/*' branch
# Or manually trigger from GitHub Actions UI:
# Actions → Gateway Service Deployment → Run workflow → Select 'staging'
```

### Deploy to Production
```powershell
# Manual trigger from GitHub Actions UI (requires 2 approvals + 5 min wait)
# Actions → Gateway Service Deployment → Run workflow → Select 'production'
# Or for MFEs:
# Actions → MFE Promotion Pipeline → Run workflow → Select 'production'
```

### Update Infrastructure
```powershell
cd infrastructure/terraform/env-prod
terraform init
terraform plan
terraform apply
```

### Rotate Secrets
```powershell
# Update secrets in AWS Secrets Manager
aws secretsmanager update-secret \
  --profile btg-prod \
  --secret-id btg/prod/gateway/mongodb-uri \
  --secret-string 'mongodb://new-connection-string'

# No ECS restart needed - secrets fetched at runtime
```

---

## 📊 Monitoring & Observability

### GitHub Actions
- [Workflow Runs](https://github.com/BTG-C/btg-devops/actions)
- [Deployment History](https://github.com/BTG-C/btg-devops/deployments)

### AWS Console Quick Links
- **ECS:** [Clusters](https://console.aws.amazon.com/ecs/v2/clusters) → Select cluster → View services
- **CloudFront:** [Distributions](https://console.aws.amazon.com/cloudfront/v3/home)
- **Secrets Manager:** [Secrets](https://console.aws.amazon.com/secretsmanager/home)
- **CloudWatch Logs:** [Log Groups](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups) → Filter by service name

### Health Checks
- **Gateway Service:** `https://<alb-url>/actuator/health`
- **Shell MFE:** `https://<cloudfront-url>/` (SPA index.html)
- **Enhancer MFE:** `https://<cloudfront-url>/` (SPA index.html)

---

## 🚨 Support & Escalation

### Communication Channels
- **Platform Team:** `#platform-team` (Slack)
- **Incident Response:** `#btg-incidents` (Slack)
- **DevOps Lead:** Contact via Slack or GitHub mentions

### Troubleshooting Resources
- [Deployment Runbook](docs/operations/DEPLOYMENT-RUNBOOK.md)
- [Rollback Procedures](docs/operations/ROLLBACK-PROCEDURES.md)
- [Configuration Flow Guide](docs/development/CONFIGURATION-FLOW.md)

---

## 🤝 Contributing

### Making Changes to Deployment Configs
1. Create feature branch: `git checkout -b config/update-gateway-memory`
2. Update service configs in `services/{service-name}/`
3. Test in dev environment first
4. Create PR with detailed description
5. Require 1 approval from DevOps team
6. Merge to `master` and deploy

### Adding New Service
1. Create service folder: `services/{service-name}/`
2. Add ECS task definition template or S3/CloudFront configs
3. Create service README.md with deployment guide
4. Configure GitHub Environment secrets
5. Add workflow (gateway-service-deployment.yml or mfe-promotion-pipeline.yml)
6. Submit PR for review

### Updating Documentation
- **Architecture:** Update `docs/architecture/OVERVIEW.md`
- **Operations:** Update `docs/operations/` guides
- **Development:** Update `docs/development/` guides
- **Infrastructure:** Update `docs/infrastructure/` guides

---

## 📜 License

Internal use only - BTG Corporation © 2026

---

## 📝 Changelog

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-01-13 | Initial repository creation | DevOps Team |

---

## 🔗 Related Repositories

### Application Repositories (with artifact pipelines)
- [btg-gateway-service](https://github.com/BTG-C/btg-gateway-service) - ✅ Artifact pipeline configured
- [btg-shell-mfe](https://github.com/BTG-C/btg-shell-mfe) - 📋 Pending artifact pipeline
- [btg-enhancer-mfe](https://github.com/BTG-C/btg-enhancer-mfe) - 📋 Pending artifact pipeline
- [btg-auth-server](https://github.com/BTG-C/btg-auth-server) - 📋 Pending artifact pipeline

### Shared Libraries
- [btg-shared-ui-lib](https://github.com/BTG-C/btg-shared-ui-lib) - Angular components
- [sass-design-system](https://github.com/BTG-C/sass-design-system) - Design tokens

### Legacy (Sunset)
- [btg-deployment-scripts](https://github.com/BTG-C/btg-deployment-scripts) - **⚠️ Deprecated, content migrated to btg-devops**

---

**Need help?** Contact platform team in Slack: `#platform-team`
