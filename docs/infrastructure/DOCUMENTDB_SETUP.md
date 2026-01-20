# DocumentDB Multi-Database Configuration

## Overview

The BTG infrastructure uses a **single DocumentDB cluster** with **multiple databases** to optimize costs while maintaining security isolation:

- **`btg_auth`**: Authentication, user management, and authorization data
- **`btg`**: Main business logic (scores, odds, enhancer data)

Each database has its own dedicated user with isolated permissions. This approach is **significantly more cost-effective** than running separate DocumentDB clusters.

---

## Architecture Benefits

### Cost Savings
- ✅ **Single cluster** = Single set of instances (saves ~50% vs. 2 clusters)
- ✅ **Shared backup/storage** = No duplicate backup costs
- ✅ **Shared replica set** = High availability for both databases

### Security
- ✅ **Isolated credentials** = `btgauth` user can only access `btg_auth` database
- ✅ **Isolated credentials** = `btgapp` user can only access `btg` database
- ✅ **TLS encryption** enforced for all connections
- ✅ **Database-level permissions** prevent cross-database access

### High Availability
- ✅ **2+ instances** = Replica set with automatic failover
- ✅ **Multi-AZ** deployment across availability zones
- ✅ **Read replicas** for better performance

---

## Database Configuration

| Database | Username | Purpose | Services |
|----------|----------|---------|----------|
| `btg_auth` | `btgauth` | User authentication, authorization, sessions | Auth Server |
| `btg` | `btgapp` | Scores, odds, enhancer business logic | Gateway, Score-Odd, Enhancer |

---

## Manual Setup Steps

### 1. Create Master Password Secret (One-time)

```bash
# Create master admin password secret
aws secretsmanager create-secret \
  --region us-east-1 \
  --name "docdb/btg-dev/master-password" \
  --description "DocumentDB master admin password for dev environment" \
  --secret-string '{"password":"YOUR_SUPER_STRONG_MASTER_PASSWORD"}'
```

**Requirements:**
- At least 16 characters
- Include uppercase, lowercase, numbers, and symbols
- Store securely (this is the root admin password)

### 2. Run Terraform to Create Cluster

```bash
cd infrastructure/terraform/env-dev
terraform init
terraform apply
```

**Terraform creates:**
- DocumentDB cluster with 2 instances (replica set)
- Security groups (only ECS tasks can connect)
- Subnet groups (private subnets only)
- Placeholder secrets for database credentials

### 3. Create Database-Specific Password Secrets

```bash
# Create btg_auth database password
aws secretsmanager create-secret \
  --region us-east-1 \
  --name "docdb/btg-dev/btg_auth/password" \
  --description "Password for btg_auth database user (btgauth)" \
  --secret-string '{"password":"YOUR_STRONG_AUTH_PASSWORD"}'

# Create btg database password
aws secretsmanager create-secret \
  --region us-east-1 \
  --name "docdb/btg-dev/btg/password" \
  --description "Password for btg database user (btgapp)" \
  --secret-string '{"password":"YOUR_STRONG_APP_PASSWORD"}'
```

**Best Practices:**
- Use different passwords for each database
- At least 16 characters each
- Store passwords in a secure password manager

### 4. Run Database Setup Script

```bash
cd infrastructure/terraform/modules/documentdb

# Set environment variables
export PROJECT_NAME="btg"
export ENVIRONMENT="dev"
export AWS_REGION="us-east-1"
export MASTER_USERNAME="btgadmin"

# Get cluster endpoint from Terraform
export CLUSTER_ENDPOINT=$(cd ../../env-dev && terraform output -raw documentdb_endpoint)

# Run setup script
bash setup-databases.sh
```

**What the script does:**
1. Downloads DocumentDB global certificate bundle
2. Connects to cluster using master credentials
3. Creates `btg_auth` database with `btgauth` user
4. Creates `btg` database with `btgapp` user
5. Tests both database connections
6. Updates Secrets Manager with full connection details

### 5. Verify Setup

```bash
# Check that all secrets exist
aws secretsmanager list-secrets --region us-east-1 --query 'SecretList[?contains(Name, `docdb/btg-dev`)].Name'

# Expected output:
# - docdb/btg-dev/master-password
# - docdb/btg-dev/btg_auth/password
# - docdb/btg-dev/btg_auth/credentials (created by Terraform)
# - docdb/btg-dev/btg/password
# - docdb/btg-dev/btg/credentials (created by Terraform)
# - docdb/btg-dev/admin (created by Terraform)
```

---

## Service Configuration

### Auth Server
Uses `btg_auth` database for user/auth data.

**Environment Variables:**
```json
{
  "SPRING_DATA_MONGODB_URI": "from-secrets-manager:docdb/btg-dev/btg_auth/credentials:uri"
}
```

**Config File (`services/auth-server/config/dev.json`):**
```json
{
  "envVars": {
    "SPRING_PROFILES_ACTIVE": "dev",
    "SPRING_DATA_MONGODB_DATABASE": "btg_auth"
  },
  "secrets": [
    {
      "name": "SPRING_DATA_MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:docdb/btg-dev/btg_auth/credentials"
    }
  ]
}
```

### Other Services (Gateway, Score-Odd, Enhancer)
Use `btg` database for business logic.

**Config File Example (`services/score-odd-service/config/dev.json`):**
```json
{
  "envVars": {
    "SPRING_PROFILES_ACTIVE": "dev",
    "SPRING_DATA_MONGODB_DATABASE": "btg"
  },
  "secrets": [
    {
      "name": "SPRING_DATA_MONGODB_URI",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:docdb/btg-dev/btg/credentials"
    }
  ]
}
```

---

## Connection Strings

### Format
```
mongodb://USERNAME:PASSWORD@ENDPOINT:27017/DATABASE?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
```

### Examples
```bash
# btg_auth database (Auth Server)
mongodb://btgauth:PASSWORD@btg-dev-cluster.cluster-abc123.us-east-1.docdb.amazonaws.com:27017/btg_auth?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false

# btg database (Other Services)
mongodb://btgapp:PASSWORD@btg-dev-cluster.cluster-abc123.us-east-1.docdb.amazonaws.com:27017/btg?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
```

**Key Parameters:**
- `tls=true` - TLS encryption required
- `replicaSet=rs0` - DocumentDB cluster replica set name
- `readPreference=secondaryPreferred` - Read from replicas when available
- `retryWrites=false` - DocumentDB doesn't support retryable writes

---

## Security Considerations

### Network Isolation
- ✅ DocumentDB deployed in **private subnets** only
- ✅ Security group allows connections **only from ECS tasks security group**
- ✅ No public internet access
- ✅ VPC-only access via internal ALB

### Authentication
- ✅ **TLS encryption** enforced at cluster level
- ✅ **Strong passwords** required (min 16 chars)
- ✅ **Separate users** for each database
- ✅ **Database-level permissions** (readWrite + dbAdmin per database)
- ❌ Users **cannot** access other databases

### Secrets Management
- ✅ All credentials stored in **AWS Secrets Manager**
- ✅ Automatic rotation supported (manual setup required)
- ✅ ECS tasks retrieve secrets at runtime
- ✅ Secrets never stored in code or config files
- ✅ IAM policies restrict access to specific secrets

---

## Cost Comparison

### Two Separate Clusters (NOT RECOMMENDED)
```
Dev Environment:
- Cluster 1 (btg_auth): 2x db.t3.medium = ~$200/month
- Cluster 2 (btg): 2x db.t3.medium = ~$200/month
- Storage (50GB each): 2x $50 = $100/month
- Backups (50GB each): 2x $25 = $50/month
Total: ~$550/month
```

### Single Cluster with Multiple Databases (CURRENT APPROACH)
```
Dev Environment:
- Cluster (shared): 2x db.t3.medium = ~$200/month
- Storage (50GB total): $50/month
- Backups (50GB total): $25/month
Total: ~$275/month

SAVINGS: $275/month (50% cost reduction)
```

---

## Troubleshooting

### Issue: Cannot connect to DocumentDB
```bash
# Check security group allows ECS tasks
aws ec2 describe-security-groups --filters Name=tag:Name,Values=btg-dev-docdb-sg

# Verify ECS tasks security group is allowed
# Should show ingress rule from btg-dev-ecs-tasks-sg on port 27017
```

### Issue: User authentication failed
```bash
# Test connection with mongo shell
mongo --ssl \
  --host btg-dev-cluster.cluster-abc123.us-east-1.docdb.amazonaws.com:27017 \
  --sslCAFile global-bundle.pem \
  --username btgauth \
  --password YOUR_PASSWORD \
  --authenticationDatabase btg_auth
```

### Issue: Secrets not found
```bash
# List all DocumentDB secrets
aws secretsmanager list-secrets \
  --region us-east-1 \
  --filters Key=name,Values=docdb/btg-dev

# Create missing secret
aws secretsmanager create-secret \
  --region us-east-1 \
  --name "docdb/btg-dev/btg_auth/password" \
  --secret-string '{"password":"YOUR_PASSWORD"}'
```

### Issue: Database doesn't exist
```bash
# Connect as master and list databases
mongo --ssl \
  --host CLUSTER_ENDPOINT:27017 \
  --sslCAFile global-bundle.pem \
  --username btgadmin \
  --password MASTER_PASSWORD \
  --eval "show dbs"

# Re-run setup script if databases missing
bash setup-databases.sh
```

---

## Maintenance

### Adding a New Database
1. Add to `variables.tf` in documentdb module:
   ```hcl
   databases = {
     btg_auth = { username = "btgauth", description = "..." }
     btg = { username = "btgapp", description = "..." }
     btg_analytics = { username = "btganalytics", description = "New analytics DB" }
   }
   ```
2. Create password secret in Secrets Manager
3. Run `terraform apply`
4. Run `setup-databases.sh` to create user

### Password Rotation
```bash
# Update password in Secrets Manager
aws secretsmanager update-secret \
  --region us-east-1 \
  --secret-id "docdb/btg-dev/btg_auth/password" \
  --secret-string '{"password":"NEW_PASSWORD"}'

# Update user password in DocumentDB
mongo --ssl \
  --host CLUSTER_ENDPOINT:27017 \
  --sslCAFile global-bundle.pem \
  --username btgadmin \
  --password MASTER_PASSWORD \
  --eval "
    db = db.getSiblingDB('btg_auth');
    db.updateUser('btgauth', { pwd: 'NEW_PASSWORD' });
  "

# Restart ECS tasks to pick up new password
aws ecs update-service \
  --cluster btg-dev-cluster \
  --service btg-dev-auth-server \
  --force-new-deployment
```

### Scaling Instances
```hcl
# In env-dev/main.tf or env-prod/main.tf
module "documentdb" {
  instance_count = 3  # Add more replicas
}
```

Run `terraform apply` to add instances.

---

## References

- [AWS DocumentDB Documentation](https://docs.aws.amazon.com/documentdb/)
- [MongoDB Connection String Format](https://docs.mongodb.com/manual/reference/connection-string/)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
