resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-docdb-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-docdb-subnet-group"
  }
}

resource "aws_security_group" "docdb" {
  name        = "${var.project_name}-${var.environment}-docdb-sg"
  description = "Security group for DocumentDB cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-docdb-sg"
  }
}

resource "aws_docdb_cluster_parameter_group" "main" {
  family      = "docdb5.0"
  name        = "${var.project_name}-${var.environment}-docdb-params"
  description = "docdb cluster parameter group"

  parameter {
    name  = "tls"
    value = "enabled"
  }
}

# Reference manually created secret
data "aws_secretsmanager_secret" "docdb_password" {
  name = "docdb/${var.project_name}-${var.environment}/master-password"
}

data "aws_secretsmanager_secret_version" "docdb_password" {
  secret_id = data.aws_secretsmanager_secret.docdb_password.id
}

locals {
  db_password = jsondecode(data.aws_secretsmanager_secret_version.docdb_password.secret_string)["password"]
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${var.project_name}-${var.environment}-cluster"
  engine                          = "docdb"
  master_username                 = var.master_username
  master_password                 = local.db_password
  backup_retention_period         = 7
  preferred_backup_window         = "03:00-05:00"  # 3-5 AM UTC (low traffic)
  skip_final_snapshot             = var.skip_final_snapshot
  deletion_protection             = var.environment == "prod" ? true : false
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  storage_encrypted               = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-docdb-cluster"
  }
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = var.instance_count
  identifier         = "${var.project_name}-${var.environment}-inst-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class
  
  tags = {
    Name = "${var.project_name}-${var.environment}-docdb-instance-${count.index}"
  }
}

# Store full connection details (password from manual secret)
resource "aws_secretsmanager_secret" "docdb_credentials" {
  name                    = "docdb/${var.project_name}-${var.environment}/admin"
  description             = "DocumentDB admin credentials"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "docdb_credentials" {
  secret_id = aws_secretsmanager_secret.docdb_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = local.db_password
    engine   = "mongo"
    host     = aws_docdb_cluster.main.endpoint
    port     = 27017
    dbname   = "admin"
  })
}

# ==============================================================================
# Multi-Database Setup with Separate Credentials
# ==============================================================================

# Reference manually created database-specific secrets
# Admin must create these secrets in AWS Secrets Manager:
#   - docdb/${var.project_name}-${var.environment}/btg_auth/password
#   - docdb/${var.project_name}-${var.environment}/btg/password
data "aws_secretsmanager_secret" "db_passwords" {
  for_each = var.databases
  name     = "docdb/${var.project_name}-${var.environment}/${each.key}/password"
}

data "aws_secretsmanager_secret_version" "db_passwords" {
  for_each  = var.databases
  secret_id = data.aws_secretsmanager_secret.db_passwords[each.key].id
}

locals {
  db_passwords = {
    for db_key, db_config in var.databases :
    db_key => jsondecode(data.aws_secretsmanager_secret_version.db_passwords[db_key].secret_string)["password"]
  }
}

# Store full connection details for each database
resource "aws_secretsmanager_secret" "db_credentials" {
  for_each = var.databases
  
  name                    = "docdb/${var.project_name}-${var.environment}/${each.key}/credentials"
  description             = "${each.value.description} - Full connection details"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  for_each  = var.databases
  secret_id = aws_secretsmanager_secret.db_credentials[each.key].id
  
  secret_string = jsonencode({
    username = each.value.username
    password = local.db_passwords[each.key]
    engine   = "mongo"
    host     = aws_docdb_cluster.main.endpoint
    port     = 27017
    dbname   = each.key
    uri      = "mongodb://${each.value.username}:${local.db_passwords[each.key]}@${aws_docdb_cluster.main.endpoint}:27017/${each.key}?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  })
}
