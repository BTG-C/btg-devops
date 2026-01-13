# Quick Start Guide

**Get up and running with BTG DevOps in 10 minutes.**

---

## Prerequisites

### Required Tools
- [ ] **Git** 2.40+
- [ ] **GitHub CLI** (`gh`) 2.40+
- [ ] **AWS CLI** v2.15+
- [ ] **Docker Desktop** 24.0+
- [ ] **Terraform** 1.6+
- [ ] **PowerShell** 7.0+ (Windows)

### Required Access
- [ ] GitHub account with access to `BTG-C` organization
- [ ] AWS IAM user with `PowerUserAccess` policy
- [ ] Slack access to `#btg-devops` channel

---

## Step 1: Install Prerequisites (5 minutes)

### Windows (PowerShell)
```powershell
# Install Chocolatey (if not installed)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install tools
choco install git gh aws-cli docker-desktop terraform -y

# Verify installations
git --version
gh --version
aws --version
docker --version
terraform --version
```

### macOS (Homebrew)
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install git gh awscli docker terraform

# Verify installations
git --version
gh --version
aws --version
docker --version
terraform --version
```

---

## Step 2: Authenticate (2 minutes)

### GitHub CLI
```powershell
gh auth login
# Select: GitHub.com
# Select: HTTPS
# Select: Login with a web browser
# Follow browser prompts
```

### AWS CLI
```powershell
aws configure
# AWS Access Key ID: [Get from AWS Console → IAM → Security credentials]
# AWS Secret Access Key: [From AWS Console]
# Default region name: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-name"
}
```

---

## Step 3: Clone Repository (1 minute)

```powershell
cd c:\Git  # Or ~/projects on macOS/Linux
git clone https://github.com/BTG-C/btg-devops.git
cd btg-devops
```

---

## Step 4: Verify Setup (2 minutes)

Run the setup verification script:

```powershell
# Windows
.\tools\verify-setup.ps1

# macOS/Linux
./tools/verify-setup.sh
```

**Expected Output:**
```
✅ Git installed (2.40.1)
✅ GitHub CLI installed (2.40.0)
✅ AWS CLI installed (2.15.0)
✅ Docker running (24.0.7)
✅ Terraform installed (1.6.6)
✅ AWS credentials valid (Account: 123456789012)
✅ GitHub authentication valid (User: your-username)
🎉 All checks passed! You're ready to deploy.
```

---

## Step 5: Your First Deployment (5 minutes)

### Deploy to Development Environment

1. **Trigger a test deployment:**
```powershell
gh workflow run promotion-pipeline.yml \
  -f service=auth-server \
  -f image_tag=test-deployment \
  -f environment=dev
```

2. **Watch the deployment:**
```powershell
# Open GitHub Actions in browser
gh workflow view promotion-pipeline.yml --web

# Or watch from terminal
gh run watch
```

3. **Verify deployment succeeded:**
```powershell
# Check service health
curl https://api-dev.btg.com/actuator/health

# Expected output:
# {"status":"UP"}
```

---

## Common First-Time Issues

### Issue: `gh: command not found`
**Solution:** Restart terminal after installing GitHub CLI

### Issue: `Docker daemon is not running`
**Solution:** 
```powershell
# Windows: Start Docker Desktop application
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# macOS: Open Docker.app
open -a Docker
```

### Issue: `AWS credentials not found`
**Solution:** Re-run `aws configure` and verify credentials with:
```powershell
aws sts get-caller-identity
```

### Issue: `Permission denied when running workflow`
**Solution:** Ensure you have `write` access to `btg-devops` repository:
```powershell
gh repo view BTG-C/btg-devops --json viewerPermission
```

---

## Next Steps

Now that you're set up:

1. **Read Architecture Overview:** [docs/architecture/OVERVIEW.md](../architecture/OVERVIEW.md)
2. **Learn Developer Workflow:** [docs/development/DEVELOPER-WORKFLOW.md](DEVELOPER-WORKFLOW.md)
3. **Understand Deployment Process:** [docs/operations/DEPLOYMENT-RUNBOOK.md](../operations/DEPLOYMENT-RUNBOOK.md)
4. **Set up Local Environment:** [docs/development/LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md)

---

## Getting Help

- **Slack:** #btg-devops
- **Email:** devops@btg.com
- **GitHub Issues:** [btg-devops/issues](https://github.com/BTG-C/btg-devops/issues)
- **Documentation:** [Full docs index](../../README.md#-documentation-index)

---

**Estimated Time:** 10-15 minutes  
**Difficulty:** Beginner  
**Last Updated:** 2026-01-13
