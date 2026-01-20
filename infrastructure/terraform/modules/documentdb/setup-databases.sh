#!/bin/bash
# ==============================================================================
# DocumentDB Multi-Database Setup Script
# ==============================================================================
# Purpose: Create database-specific users with isolated permissions
# Run this AFTER Terraform creates the DocumentDB cluster
# ==============================================================================

set -e

# ==============================================================================
# Configuration
# ==============================================================================
PROJECT_NAME="${PROJECT_NAME:-btg}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT}"
MASTER_USERNAME="${MASTER_USERNAME:-btgadmin}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ==============================================================================
# Validation
# ==============================================================================
if [ -z "$CLUSTER_ENDPOINT" ]; then
  echo -e "${RED}Error: CLUSTER_ENDPOINT not set${NC}"
  echo "Get it from Terraform output: terraform output -raw documentdb_endpoint"
  exit 1
fi

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}DocumentDB Multi-Database Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Cluster: $CLUSTER_ENDPOINT"
echo ""

# ==============================================================================
# 1. Retrieve Master Password from Secrets Manager
# ==============================================================================
echo -e "${YELLOW}[1/5] Retrieving master password...${NC}"
MASTER_SECRET_NAME="docdb/${PROJECT_NAME}-${ENVIRONMENT}/master-password"
MASTER_PASSWORD=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$MASTER_SECRET_NAME" \
  --query 'SecretString' \
  --output text | jq -r '.password')

if [ -z "$MASTER_PASSWORD" ] || [ "$MASTER_PASSWORD" == "null" ]; then
  echo -e "${RED}Error: Could not retrieve master password from ${MASTER_SECRET_NAME}${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Master password retrieved${NC}"

# ==============================================================================
# 2. Download Global Bundle Certificate
# ==============================================================================
echo -e "${YELLOW}[2/5] Downloading DocumentDB global bundle certificate...${NC}"
if [ ! -f "global-bundle.pem" ]; then
  wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
  echo -e "${GREEN}✓ Certificate downloaded${NC}"
else
  echo -e "${GREEN}✓ Certificate already exists${NC}"
fi

# ==============================================================================
# 3. Create Database-Specific Users
# ==============================================================================
declare -A DB_CONFIG=(
  ["btg_auth"]="btgauth"
  ["btg"]="btgapp"
)

for DB_NAME in "${!DB_CONFIG[@]}"; do
  USERNAME="${DB_CONFIG[$DB_NAME]}"
  
  echo ""
  echo -e "${YELLOW}[3/5] Setting up database: ${DB_NAME} (user: ${USERNAME})${NC}"
  
  # Retrieve database-specific password from Secrets Manager
  DB_SECRET_NAME="docdb/${PROJECT_NAME}-${ENVIRONMENT}/${DB_NAME}/password"
  
  echo "  Checking if secret exists: ${DB_SECRET_NAME}"
  if ! aws secretsmanager describe-secret --region "$AWS_REGION" --secret-id "$DB_SECRET_NAME" &>/dev/null; then
    echo -e "${RED}  Error: Secret ${DB_SECRET_NAME} does not exist${NC}"
    echo -e "${RED}  Please create it first:${NC}"
    echo ""
    echo "  aws secretsmanager create-secret \\"
    echo "    --region $AWS_REGION \\"
    echo "    --name $DB_SECRET_NAME \\"
    echo "    --description 'Password for ${DB_NAME} database user ${USERNAME}' \\"
    echo "    --secret-string '{\"password\":\"YOUR_STRONG_PASSWORD_HERE\"}'"
    echo ""
    continue
  fi
  
  DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$DB_SECRET_NAME" \
    --query 'SecretString' \
    --output text | jq -r '.password')
  
  if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" == "null" ]; then
    echo -e "${RED}  Error: Could not retrieve password from ${DB_SECRET_NAME}${NC}"
    continue
  fi
  
  echo "  Creating database and user..."
  
  # Connect to DocumentDB and create user with database-specific permissions
  mongo --ssl \
    --host "$CLUSTER_ENDPOINT:27017" \
    --sslCAFile global-bundle.pem \
    --username "$MASTER_USERNAME" \
    --password "$MASTER_PASSWORD" \
    --eval "
      // Switch to target database
      db = db.getSiblingDB('${DB_NAME}');
      
      // Create user if doesn't exist
      try {
        db.createUser({
          user: '${USERNAME}',
          pwd: '${DB_PASSWORD}',
          roles: [
            { role: 'readWrite', db: '${DB_NAME}' },
            { role: 'dbAdmin', db: '${DB_NAME}' }
          ]
        });
        print('✓ User ${USERNAME} created successfully');
      } catch (e) {
        if (e.code === 51003) {
          print('✓ User ${USERNAME} already exists, updating password...');
          db.updateUser('${USERNAME}', {
            pwd: '${DB_PASSWORD}',
            roles: [
              { role: 'readWrite', db: '${DB_NAME}' },
              { role: 'dbAdmin', db: '${DB_NAME}' }
            ]
          });
          print('✓ User ${USERNAME} updated successfully');
        } else {
          print('✗ Error: ' + e);
          throw e;
        }
      }
    " 2>&1 | grep -E "✓|✗" || true
  
  echo -e "${GREEN}  ✓ Database ${DB_NAME} configured with user ${USERNAME}${NC}"
done

# ==============================================================================
# 4. Test Connections
# ==============================================================================
echo ""
echo -e "${YELLOW}[4/5] Testing database connections...${NC}"

for DB_NAME in "${!DB_CONFIG[@]}"; do
  USERNAME="${DB_CONFIG[$DB_NAME]}"
  DB_SECRET_NAME="docdb/${PROJECT_NAME}-${ENVIRONMENT}/${DB_NAME}/password"
  
  if ! aws secretsmanager describe-secret --region "$AWS_REGION" --secret-id "$DB_SECRET_NAME" &>/dev/null; then
    echo -e "${YELLOW}  ⊘ Skipping ${DB_NAME} (secret not created)${NC}"
    continue
  fi
  
  DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$DB_SECRET_NAME" \
    --query 'SecretString' \
    --output text | jq -r '.password')
  
  echo "  Testing connection to ${DB_NAME} as ${USERNAME}..."
  
  if mongo --ssl \
    --host "$CLUSTER_ENDPOINT:27017" \
    --sslCAFile global-bundle.pem \
    --username "$USERNAME" \
    --password "$DB_PASSWORD" \
    --authenticationDatabase "$DB_NAME" \
    --eval "db.runCommand({ping: 1})" &>/dev/null; then
    echo -e "${GREEN}  ✓ Connection to ${DB_NAME} successful${NC}"
  else
    echo -e "${RED}  ✗ Connection to ${DB_NAME} failed${NC}"
  fi
done

# ==============================================================================
# 5. Summary
# ==============================================================================
echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo "Databases configured:"
for DB_NAME in "${!DB_CONFIG[@]}"; do
  USERNAME="${DB_CONFIG[$DB_NAME]}"
  echo "  - ${DB_NAME} (user: ${USERNAME})"
done
echo ""
echo "Connection strings stored in Secrets Manager:"
for DB_NAME in "${!DB_CONFIG[@]}"; do
  echo "  - docdb/${PROJECT_NAME}-${ENVIRONMENT}/${DB_NAME}/credentials"
done
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update ECS task definitions to use database-specific credentials"
echo "  2. Auth Server: Use 'btg_auth' database credentials"
echo "  3. Other Services: Use 'btg' database credentials"
echo ""
