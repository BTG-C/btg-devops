# 📊 Terraform Module Dependency Reference

**Quick reference for understanding module dependencies and execution order.**

---

## 🎯 GOLDEN RULES

1. **Foundation First:** Networking and storage MUST be created before everything else
2. **IAM After Infrastructure:** IAM module needs S3/CloudFront ARNs, so create them first
3. **Platform Before Apps:** ECS cluster and database must exist before deploying services
4. **Avoid Circular Dependencies:** Never reference module outputs from modules created later

---

## 📊 DEPENDENCY MATRIX

| Module | Depends On | Provides To | Layer |
|--------|------------|-------------|-------|
| `networking` | *none* | ecs_platform, documentdb, all services | 1 |
| `mfe_s3` | *none* | mfe_cloudfront, iam | 1 |
| `acm_certificate` | *none* (data source) | mfe_cloudfront, ecs_platform | 2 |
| `mfe_cloudfront` | mfe_s3, acm_certificate | iam, route53 | 2 |
| `route53` | mfe_cloudfront | *none* | 2 |
| `iam` | mfe_s3, mfe_cloudfront | all services, auth_server_sns | 3 |
| `auth_notifications_topic` (SNS) | *none* | auth_server_sns, auth_service | 4 |
| `auth_server_sns` (policy) | iam, sns | *none* | 4 |
| `ecs_platform` | networking | documentdb, all services | 5 |
| `documentdb` | networking, ecs_platform | all services | 5 |
| `gateway_service` | iam, ecs_platform, networking, documentdb | *none* | 6 |
| `auth_service` | iam, ecs_platform, networking, documentdb, sns | *none* | 6 |
| `score_odd_service` | iam, ecs_platform, networking, documentdb | *none* | 6 |
| `enhancer_service` | iam, ecs_platform, networking, documentdb | *none* | 6 |
| `budget` | *none* | *none* | 7 |

---

## 🏗️ LAYERED ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 7: MONITORING                                         │
│ ├── budget                                                  │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: APPLICATIONS                                       │
│ ├── gateway_service                                         │
│ ├── auth_service                                            │
│ ├── score_odd_service                                       │
│ └── enhancer_service                                        │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: PLATFORM                                           │
│ ├── ecs_platform                                            │
│ └── documentdb                                              │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: MESSAGING                                          │
│ ├── auth_notifications_topic (SNS)                          │
│ └── auth_server_sns (IAM policy attachment)                 │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: IAM                                                │
│ └── iam (centralized - ALL roles & policies)                │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: INFRASTRUCTURE                                     │
│ ├── acm_certificate                                         │
│ ├── mfe_cloudfront                                          │
│ └── route53                                                 │
└─────────────────────────────────────────────────────────────┘
                            ▲
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: FOUNDATION                                         │
│ ├── networking                                              │
│ └── mfe_s3                                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 DETAILED DEPENDENCY FLOWS

### Networking Flow
```
networking
  ├─→ ecs_platform (vpc_id, subnets)
  ├─→ documentdb (vpc_id, subnets)
  ├─→ gateway_service (vpc_id, subnets, security groups)
  ├─→ auth_service (vpc_id, subnets, security groups)
  ├─→ score_odd_service (vpc_id, subnets, security groups)
  └─→ enhancer_service (vpc_id, subnets, security groups)
```

### IAM Flow
```
iam
  ├─→ gateway_service (execution_role_arn only)
  ├─→ auth_service (execution_role_arn, task_role_arn)
  ├─→ score_odd_service (execution_role_arn, task_role_arn)
  ├─→ enhancer_service (execution_role_arn, task_role_arn)
  └─→ auth_server_sns (task_role_names["auth-server"])
```

### ECS Platform Flow
```
ecs_platform
  ├─→ documentdb (ecs_tasks_sg_id for security group rules)
  ├─→ gateway_service (cluster_id, listener_arn, security groups)
  ├─→ auth_service (cluster_id, listener_arn, security groups)
  ├─→ score_odd_service (cluster_id, listener_arn, security groups)
  └─→ enhancer_service (cluster_id, listener_arn, security groups)
```

### DocumentDB Flow
```
documentdb
  ├─→ gateway_service (endpoint, port)
  ├─→ auth_service (endpoint, port)
  ├─→ score_odd_service (endpoint, port)
  └─→ enhancer_service (endpoint, port)
```

### SNS Flow
```
auth_notifications_topic
  ├─→ auth_server_sns (topic_arn for IAM policy)
  └─→ auth_service (topic_arn for application code)
```

---

## ⚠️ ANTI-PATTERNS TO AVOID

### ❌ Forward References
```hcl
# BAD: IAM module references S3 module that doesn't exist yet
module "iam" { ... }               # Line 100
module "mfe_s3" { ... }            # Line 200 - CREATED AFTER IAM!

# IAM module tries to use:
mfe_s3_bucket_arn = module.mfe_s3.bucket_arn  # ERROR: module doesn't exist yet
```

**Solution:** Always create dependency modules BEFORE modules that use them:
```hcl
# GOOD: S3 created before IAM
module "mfe_s3" { ... }            # Line 100
module "iam" {
  mfe_s3_bucket_arn = module.mfe_s3.bucket_arn  # ✅ S3 already exists
}
```

---

### ❌ Circular Dependencies
```hcl
# BAD: Module A needs Module B, Module B needs Module A
module "service_a" {
  security_group_id = module.service_b.sg_id
}

module "service_b" {
  security_group_id = module.service_a.sg_id
}
```

**Solution:** Extract shared resources to a common module:
```hcl
# GOOD: Shared security group module
module "shared_security_groups" { ... }

module "service_a" {
  security_group_id = module.shared_security_groups.common_sg_id
}

module "service_b" {
  security_group_id = module.shared_security_groups.common_sg_id
}
```

---

### ❌ Fragile String Parsing
```hcl
# BAD: Extracting role name from ARN using split()
role = split("/", module.iam.ecs_task_role_arns["auth-server"])[1]
```

**Issues:**
- Hardcoded array index
- Assumes ARN format never changes
- Breaks if AWS changes ARN structure

**Solution:** Add explicit outputs to modules:
```hcl
# GOOD: modules/iam/outputs.tf
output "ecs_task_role_names" {
  value = { for k, v in aws_iam_role.ecs_task : k => v.name }
}

# Usage:
role = module.iam.ecs_task_role_names["auth-server"]  # ✅ Type-safe
```

---

### ❌ Scattered IAM Resources
```hcl
# BAD: IAM roles spread across multiple modules
modules/ecs-service/main.tf:
  resource "aws_iam_role" "ecs_task_role" { ... }

modules/lambda/main.tf:
  resource "aws_iam_role" "lambda_role" { ... }

modules/s3/main.tf:
  resource "aws_iam_role" "s3_role" { ... }
```

**Issues:**
- Hard to audit permissions
- Duplicate policy logic
- Difficult to enforce least privilege

**Solution:** Centralize IAM in one module:
```hcl
# GOOD: modules/iam/main.tf
resource "aws_iam_role" "ecs_task_execution" {
  for_each = var.ecs_services  # All ECS roles in one place
  ...
}

resource "aws_iam_role" "ecs_task" {
  for_each = var.ecs_services_with_task_roles
  ...
}
```

---

## 🎯 BEST PRACTICES

### ✅ Use Maps for Multi-Service Configuration
```hcl
variable "ecs_services" {
  type = map(object({
    cpu    = number
    memory = number
    # ... other config
  }))
}

resource "aws_iam_role" "ecs_task_execution" {
  for_each = var.ecs_services
  name     = "${var.environment}-${each.key}-execution-role"
  # ...
}
```

**Benefits:**
- Single source of truth
- Easy to add/remove services
- Consistent naming

---

### ✅ Provide Both ARNs and Names as Outputs
```hcl
output "ecs_task_role_arns" {
  value = { for k, v in aws_iam_role.ecs_task : k => v.arn }
}

output "ecs_task_role_names" {
  value = { for k, v in aws_iam_role.ecs_task : k => v.name }
}
```

**Benefits:**
- Flexibility for consumers
- No need for string parsing
- Type-safe references

---

### ✅ Use Conditional Resources for Optional Features
```hcl
resource "aws_iam_role_policy" "optional_s3_access" {
  count = var.enable_s3_access ? 1 : 0
  role  = aws_iam_role.main.name
  # ...
}
```

**Benefits:**
- Environment-specific features
- Cost optimization
- Reduced complexity in dev environments

---

### ✅ Document Dependencies in Module Comments
```hcl
# ------------------------------------------------------------------------------
# 6. IAM Module (Centralized)
# ------------------------------------------------------------------------------
# Dependencies:
# - mfe_s3 (for GitHub Actions role)
# - mfe_cloudfront (for GitHub Actions role)
# 
# Provides:
# - ECS task execution roles (all services)
# - ECS task roles (services needing AWS SDK access)
# - GitHub Actions OIDC role (MFE deployment)
# ------------------------------------------------------------------------------
module "iam" {
  source = "../modules/iam"
  # ...
}
```

---

## 🔧 TROUBLESHOOTING GUIDE

### Error: "Module not found"
**Symptom:**
```
Error: Module not found: module.some_module.output_value
```

**Cause:** Module is defined later in the file (forward reference)

**Fix:** Move the module definition earlier, or reorder modules according to dependency layers

---

### Error: "Resource already declared"
**Symptom:**
```
Error: Resource "aws_iam_role_policy" "my_policy" already declared at main.tf:100
```

**Cause:** Duplicate resource block

**Fix:** Search for duplicate resource names:
```powershell
Get-Content main.tf | Select-String -Pattern '^resource "'
```

---

### Error: "Invalid index"
**Symptom:**
```
Error: Invalid index: The given key does not identify an element in this collection value.
```

**Cause:** Module output map doesn't contain expected key

**Fix:** Verify the key exists in the module's `outputs.tf`:
```hcl
# Check what keys are available
output "debug_available_keys" {
  value = keys(aws_iam_role.ecs_task)
}
```

---

## 📚 RELATED DOCUMENTATION

- [IAM Module README](./iam/README.md)
- [SNS Module README](./sns/README.md)
- [ECS Service Module README](./ecs-service/README.md)
- [Validation Report](../env-dev/VALIDATION_REPORT.md)

---

**Last Updated:** 2024  
**Maintained By:** DevOps Team
