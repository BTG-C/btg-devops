# BTG DevOps Repository

**Centralized deployment orchestration, infrastructure as code, and operational documentation for all BTG services.**

---

## 🎯 Purpose

This repository implements the **2026 Future-Proof Multi-Repo Immutable Pipeline** architecture, separating deployment concerns from application code.

### Key Principles
- **Immutable Artifacts:** Build once in app repos, deploy many times from here
- **Environment Governance:** All env-specific configs and approvals managed centrally
- **Zero Hardcoding:** Secret ARNs and configs via GitHub Environments
- **Audit Trail:** All deployments tracked through GitHub Actions runs

---

## 📁 Repository Structure

```
btg-devops/
├── .github/
│   └── workflows/              # Deployment orchestration
│       ├── promotion-pipeline.yml
│       ├── rollback-pipeline.yml
│       └── terraform-apply.yml
│
├── services/                   # Service-specific deployment configs
│   ├── auth-server/
│   ├── gateway-service/
│   ├── shell-mfe/
│   └── enhancer-mfe/
│
├── infrastructure/             # Terraform IaC
│   ├── terraform/
│   └── scripts/
│
├── docs/                       # Documentation organized by domain
│   ├── architecture/
│   ├── operations/
│   ├── security/
│   └── development/
│
└── tools/                      # Helper scripts and utilities
    ├── health-checks/
    └── migrations/
```

---

## 🚀 Quick Start

### Prerequisites
- GitHub CLI (`gh`) installed
- AWS CLI v2 installed and configured
- Docker installed
- Terraform 1.6+ installed

### First-Time Setup
```powershell
# 1. Clone repository
cd c:\Git
git clone https://github.com/BTG-C/btg-devops.git
cd btg-devops

# 2. Initialize Git repository
git init
git branch -M main

# 3. Set up GitHub repository
gh repo create BTG-C/btg-devops --private --source=. --remote=origin

# 4. Configure GitHub Environments
./tools/setup-github-environments.ps1

# 5. Verify AWS credentials
aws sts get-caller-identity

# 6. Initialize Terraform
cd infrastructure/terraform/global
terraform init
```

### Deploy Your First Service
```powershell
# Trigger deployment via GitHub Actions UI or:
gh workflow run promotion-pipeline.yml \
  -f service=auth-server \
  -f image_tag=abc123 \
  -f environment=dev
```

---

## 📚 Documentation Index

### Getting Started
- [Quick Start Guide](docs/development/QUICK-START.md) - 10-minute setup
- [Architecture Overview](docs/architecture/OVERVIEW.md) - System design
- [Migration Guide](docs/operations/MIGRATION-FROM-OLD-SYSTEM.md) - Transition plan

### Development
- [Developer Workflow](docs/development/DEVELOPER-WORKFLOW.md) - Day-to-day usage
- [Adding New Service](docs/development/ADD-NEW-SERVICE.md) - Onboarding checklist
- [Testing Strategy](docs/development/TESTING-STRATEGY.md) - CI/CD testing

### Operations
- [Deployment Runbook](docs/operations/DEPLOYMENT-RUNBOOK.md) - Step-by-step deployment
- [Rollback Procedures](docs/operations/ROLLBACK-PROCEDURES.md) - Emergency response
- [Disaster Recovery](docs/operations/DISASTER-RECOVERY.md) - Business continuity
- [Monitoring & Alerting](docs/operations/MONITORING.md) - Observability setup
- [On-Call Guide](docs/operations/ON-CALL-GUIDE.md) - Incident response

### Security
- [Secrets Management](docs/security/SECRETS-MANAGEMENT.md) - AWS Secrets Manager
- [IAM Policies](docs/security/IAM-POLICIES.md) - Least privilege
- [Compliance](docs/security/COMPLIANCE.md) - SOC 2, audit trails
- [Security Checklist](docs/security/SECURITY-CHECKLIST.md) - Pre-deployment validation

### Architecture
- [System Architecture](docs/architecture/SYSTEM-ARCHITECTURE.md) - Full diagram
- [CI/CD Pipeline](docs/architecture/CICD-PIPELINE.md) - Artifact → Promotion flow
- [Repository Strategy](docs/architecture/REPOSITORY-STRATEGY.md) - Multi-repo design
- [Technology Decisions](docs/architecture/TECHNOLOGY-DECISIONS.md) - Why GHCR, why centralized

### Troubleshooting
- [Common Issues](docs/troubleshooting/COMMON-ISSUES.md) - FAQ with solutions
- [Debug Workflows](docs/troubleshooting/DEBUG-WORKFLOWS.md) - GitHub Actions debugging
- [ECS Issues](docs/troubleshooting/ECS-ISSUES.md) - Container startup failures
- [Network Issues](docs/troubleshooting/NETWORK-ISSUES.md) - VPC, ALB, CloudFront

---

## 🏗️ Services

### Backend Services (ECS Fargate)
| Service | Description | Health Check | Docs |
|---------|-------------|--------------|------|
| [auth-server](services/auth-server/) | OAuth2/OIDC Authorization | `/actuator/health` | [README](services/auth-server/README.md) |
| [gateway-service](services/gateway-service/) | API Gateway (Spring Cloud) | `/actuator/health` | [README](services/gateway-service/README.md) |

### Frontend Services (S3 + CloudFront)
| Service | Description | URL | Docs |
|---------|-------------|-----|------|
| [shell-mfe](services/shell-mfe/) | Angular Shell (Host) | `/` | [README](services/shell-mfe/README.md) |
| [enhancer-mfe](services/enhancer-mfe/) | Angular MFE | `/mfe-bundles/enhancer/` | [README](services/enhancer-mfe/README.md) |

---

## 🔐 GitHub Environments

### Development (`dev`)
- **Auto-deploy:** Push to `develop` branch in app repos
- **Approvals:** None
- **AWS Account:** 123456789012
- **Region:** us-east-1
- **ECS Cluster:** btg-dev-cluster
- **S3 Bucket:** btg-dev-blue
- **CloudFront:** E1234567890ABC

### Staging (`staging`)
- **Auto-deploy:** Push to `release/*` branch in app repos
- **Approvals:** None (QA validation required before prod)
- **AWS Account:** 123456789012
- **Region:** us-east-1
- **ECS Cluster:** btg-staging-cluster
- **S3 Bucket:** btg-staging-blue
- **CloudFront:** E0987654321XYZ

### Production (`production`)
- **Auto-deploy:** None (manual only)
- **Approvals:** 2 required (DevOps Lead + Release Manager)
- **Wait timer:** 5 minutes
- **AWS Account:** 123456789012
- **Region:** us-east-1
- **ECS Cluster:** btg-prod-cluster
- **S3 Bucket:** btg-prod-blue
- **CloudFront:** EABCDEF123456

---

## 🛠️ Common Tasks

### Deploy to Development
```powershell
# Automatically triggered when app repo pushes to 'develop' branch
# No manual action needed
```

### Deploy to Staging
```powershell
# Automatically triggered when app repo pushes to 'release/*' branch
# No manual action needed
```

### Deploy to Production
```powershell
# Manual approval required
gh workflow run promotion-pipeline.yml \
  -f service=auth-server \
  -f image_tag=abc123-20260113-143052 \
  -f environment=production
```

### Rollback Production
```powershell
# Find previous stable version from GitHub Actions history
gh workflow run rollback-pipeline.yml \
  -f service=auth-server \
  -f image_tag=xyz789-20260112-094521 \
  -f environment=production
```

### Rotate Secrets
```powershell
# See docs/security/SECRETS-MANAGEMENT.md for detailed guide
aws secretsmanager rotate-secret \
  --secret-id btg/prod/auth-server/mongodb-uri
```

### Update Infrastructure
```powershell
cd infrastructure/terraform/env-prod
terraform plan
terraform apply
```

---

## 📊 Monitoring & Dashboards

### CloudWatch Dashboards
- [Dev Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-dev)
- [Staging Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-staging)
- [Production Dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=btg-prod)

### GitHub Actions
- [Workflow Runs](https://github.com/BTG-C/btg-devops/actions)
- [Deployment History](https://github.com/BTG-C/btg-devops/deployments)

### AWS Console Quick Links
- [ECS Clusters](https://console.aws.amazon.com/ecs/v2/clusters)
- [CloudFront Distributions](https://console.aws.amazon.com/cloudfront/v3/home)
- [Secrets Manager](https://console.aws.amazon.com/secretsmanager/home)
- [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups)

---

## 🚨 Emergency Contacts

### On-Call Rotation
- **DevOps Lead:** [Name] - Slack: @devops-lead
- **Release Manager:** [Name] - Slack: @release-manager
- **Platform Team:** #platform-team
- **Incident Channel:** #btg-incidents

### Escalation Path
1. **Tier 1:** On-call engineer (initial response)
2. **Tier 2:** DevOps Lead (30 min escalation)
3. **Tier 3:** CTO (critical outages)

---

## 🤝 Contributing

### Making Changes to Deployment Configs
1. Create feature branch: `git checkout -b config/update-auth-server-memory`
2. Update service configs in `services/{service-name}/`
3. Test in dev environment first
4. Create PR with detailed description
5. Require 1 approval from DevOps team
6. Merge to `main` and deploy

### Adding New Service
1. Follow [Adding New Service Guide](docs/development/ADD-NEW-SERVICE.md)
2. Create service folder structure
3. Add ECS task definition blueprint
4. Configure GitHub Environment variables
5. Create service README
6. Submit PR for review

### Updating Documentation
- **Architecture changes:** Update `docs/architecture/`
- **Operational procedures:** Update `docs/operations/`
- **Security policies:** Update `docs/security/`
- **Development guides:** Update `docs/development/`

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

### Application Repositories
- [btg-auth-server](https://github.com/BTG-C/btg-auth-server) - Code only, no deployment configs
- [btg-gateway-service](https://github.com/BTG-C/btg-gateway-service) - Code only, no deployment configs
- [btg-shell-mfe](https://github.com/BTG-C/btg-shell-mfe) - Angular shell application
- [btg-enhancer-mfe](https://github.com/BTG-C/btg-enhancer-mfe) - Angular micro-frontend

### Shared Libraries
- [btg-shared-ui-lib](https://github.com/BTG-C/btg-shared-ui-lib) - Angular components
- [sass-design-system](https://github.com/BTG-C/sass-design-system) - Design tokens

### Legacy (Deprecated)
- [btg-deployment-scripts](https://github.com/BTG-C/btg-deployment-scripts) - **⚠️ Being phased out, use btg-devops instead**

---

**Need help?** Contact DevOps team in Slack: `#btg-devops` or email: devops@btg.com
