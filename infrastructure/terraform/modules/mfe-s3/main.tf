# ==============================================================================
# MFE S3 Bucket Module
# ==============================================================================
# Purpose: Single S3 bucket for hosting all MFEs (Shell + remote MFEs)
# Structure: /index.html (Shell), /mfe-bundles/enhancer/, /assets/
# ==============================================================================

resource "aws_s3_bucket" "mfe_bucket" {
  bucket = "${var.project_name}-${var.environment}-mfe-assets"

  tags = {
    Name        = "${var.project_name}-${var.environment}-mfe-assets"
    Environment = var.environment
    Purpose     = "MFE Hosting"
  }
}

resource "aws_s3_bucket_versioning" "mfe_bucket" {
  bucket = aws_s3_bucket.mfe_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mfe_bucket" {
  bucket = aws_s3_bucket.mfe_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mfe_bucket" {
  bucket = aws_s3_bucket.mfe_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mfe_bucket" {
  bucket = aws_s3_bucket.mfe_bucket.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }

  rule {
    id     = "abort_incomplete_uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.mfe_bucket]
}

resource "aws_s3_bucket_cors_configuration" "mfe_bucket" {
  bucket = aws_s3_bucket.mfe_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
