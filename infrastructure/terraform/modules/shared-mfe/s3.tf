# ==============================================================================
# S3 BUCKETS FOR MFE HOSTING
# ==============================================================================
# Single bucket architecture: All MFEs and Shell hosted in one bucket
# Structure: /index.html (Shell), /mfe-bundles/enhancer/, /assets/shell/, /assets/enhancer/

# Blue Environment S3 Bucket
resource "aws_s3_bucket" "mfe_bucket" {
  bucket = "${var.project_name}-${var.environment}-blue"

  tags = merge(local.common_tags, {
    Description = "S3 bucket hosting Shell and all MFEs (single bucket architecture)"
    Environment = "${var.environment}-blue"
    Purpose     = "Shell-MFE-Unified"
  })
}

resource "aws_s3_bucket_versioning" "mfe_bucket_versioning" {
  bucket = aws_s3_bucket.mfe_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mfe_bucket_pab" {
  bucket = aws_s3_bucket.mfe_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.mfe_bucket]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mfe_bucket_encryption" {
  bucket = aws_s3_bucket.mfe_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # S3-managed encryption (production-ready, simpler)
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mfe_bucket_lifecycle" {
  bucket = aws_s3_bucket.mfe_bucket.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = local.environment_config.retention_days
    }
  }

  rule {
    id     = "abort_incomplete_uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.mfe_bucket_versioning]
}

# ==============================================================================
# GREEN ENVIRONMENT S3 BUCKET (Blue-Green Deployment)
# ==============================================================================

resource "aws_s3_bucket" "mfe_bucket_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-green"

  tags = merge(local.common_tags, {
    Description = "S3 bucket for blue-green deployment (green environment)"
    Environment = "${var.environment}-green"
    Purpose     = "Shell-MFE-Unified"
  })
}

resource "aws_s3_bucket_versioning" "mfe_bucket_versioning_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = aws_s3_bucket.mfe_bucket_green[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mfe_bucket_pab_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = aws_s3_bucket.mfe_bucket_green[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mfe_bucket_encryption_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = aws_s3_bucket.mfe_bucket_green[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # S3-managed encryption
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mfe_bucket_lifecycle_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = aws_s3_bucket.mfe_bucket_green[0].id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = local.environment_config.retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.mfe_bucket_versioning_green]
}

# ==============================================================================
# S3 BUCKET POLICIES
# ==============================================================================

resource "aws_s3_bucket_policy" "mfe_bucket_policy" {
  bucket = aws_s3_bucket.mfe_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mfe_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.mfe_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "mfe_bucket_policy_green" {
  count  = local.enable_blue_green ? 1 : 0
  bucket = aws_s3_bucket.mfe_bucket_green[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mfe_bucket_green[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.mfe_distribution_green[0].arn
          }
        }
      }
    ]
  })
}