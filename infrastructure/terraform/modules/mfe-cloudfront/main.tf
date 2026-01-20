# ==============================================================================
# MFE CloudFront Distribution Module
# ==============================================================================
# Purpose: CDN for global MFE delivery with optimized caching
# ==============================================================================

# Origin Access Control for secure S3 access
resource "aws_cloudfront_origin_access_control" "mfe_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} MFE"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Security Headers Policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  comment = "Security headers for MFE"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    
    content_type_options {
      override = true
    }
    
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "mfe_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CDN for ${var.project_name} ${var.environment} MFE"
  price_class         = var.price_class
  aliases             = var.domain_name != "" ? [var.domain_name] : []

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-MFE-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.mfe_oac.id
  }

  # Default: No cache (for SPA routing)
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-MFE-Origin"
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # No cache for config files (runtime configuration)
  ordered_cache_behavior {
    path_pattern           = "config/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # No cache for MFE remote entry points
  ordered_cache_behavior {
    path_pattern           = "mfe-bundles/*/remoteEntry.json"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # No cache for Shell remote entry
  ordered_cache_behavior {
    path_pattern           = "remoteEntry.json"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache static assets for 1 year
  ordered_cache_behavior {
    path_pattern           = "assets/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache JavaScript files for 1 year
  ordered_cache_behavior {
    path_pattern           = "*.js"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Cache CSS files for 1 year
  ordered_cache_behavior {
    path_pattern           = "*.css"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-MFE-Origin"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # SPA routing - redirect 404/403 to index.html
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == ""
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mfe-distribution"
    Environment = var.environment
  }
}

# S3 Bucket Policy - Allow CloudFront access
resource "aws_s3_bucket_policy" "mfe_bucket_policy" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.mfe_distribution.arn
          }
        }
      }
    ]
  })
}
