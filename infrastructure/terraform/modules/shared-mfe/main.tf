# ==============================================================================
# MFE Infrastructure Module - S3 + CloudFront
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket for MFE Hosting (Shared by all MFEs)
resource "aws_s3_bucket" "mfe_assets" {
  bucket = "${var.project_name}-${var.environment}-mfe-assets"
  
  force_destroy = var.environment != "prod"

  tags = {
    Name = "${var.project_name}-${var.environment}-mfe-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "mfe_assets" {
  bucket = aws_s3_bucket.mfe_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors" "mfe_assets" {
  bucket = aws_s3_bucket.mfe_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"] # CloudFront will restrict access, or explicit domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ----------------------------------------------------------------------------
# CloudFront Distribution
# -----------------------------------------------------------------------------

# Origin Access Control (OAC) for secure S3 access
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for ${var.project_name} MFE Assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "MFE CDN for ${var.project_name} (${var.environment}) - Shared Bucket"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Use PriceClass_All for global perf if needed

  # Custom Domain Configuration
  aliases = var.domain_name != "" ? [var.domain_name] : []

  origin {
    domain_name              = aws_s3_bucket.mfe_assets.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.mfe_assets.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.mfe_assets.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # SPA Routing (Rewrite 404/403 to index.html to let Angular handle routing)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == ""
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-distribution"
  }
}

# ----------------------------------------------------------------------------
# S3 Bucket Policy (Allow CloudFront)
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.mfe_assets.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.mfe_assets.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# GitHub Actions IAM Role (OIDC)
resource "aws_iam_openid_connect_provider" "github" {
  count           = length(data.aws_iam_openid_connect_provider.github_existing[*].arn) > 0 ? 0 : 1
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github_existing" {
  count = 1
  url   = "https://token.actions.githubusercontent.com"
  
  lifecycle {
    postcondition {
      condition     = self.arn != null || self.arn == null
      error_message = "OIDC provider check"
    }
  }
}

locals {
  github_oidc_provider_arn = length(data.aws_iam_openid_connect_provider.github_existing[*].arn) > 0 ? data.aws_iam_openid_connect_provider.github_existing[0].arn : aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub": "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_upload" {
  name = "s3-upload-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.mfe_assets.arn,
          "${aws_s3_bucket.mfe_assets.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = [
          aws_cloudfront_distribution.main.arn
        ]
      }
    ]
  })
}
