# ==============================================================================
# CLOUDFRONT DISTRIBUTIONS
# ==============================================================================
# Scalability: Supports unlimited MFEs (tested up to 30+)
# - Wildcard path patterns (mfe-bundles/*/remoteEntry.json) handle any MFE name
# - No hardcoded MFE-specific configurations required
# - Simply deploy new MFE to /mfe-bundles/{mfe-name}/ and it works automatically

# Security Headers Policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  comment = "Security headers policy for Angular MFE"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                   = true
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
  
  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow"
      override = false
    }
  }

  tags = merge(local.common_tags, {
    Description = "Security headers policy for CloudFront distribution"
  })
}

# Origin Access Control
resource "aws_cloudfront_origin_access_control" "mfe_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} - secure S3 access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Blue Environment CloudFront Distribution
resource "aws_cloudfront_distribution" "mfe_distribution" {
  origin {
    domain_name              = aws_s3_bucket.mfe_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.mfe_oac.id
    origin_id                = "${var.project_name}-s3-origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CDN for ${var.project_name} ${var.environment} MFE"
  
  price_class = local.environment_config.price_class
  aliases     = local.has_custom_domain ? [var.domain_name] : []

  default_cache_behavior {
    allowed_methods                = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "${var.project_name}-s3-origin"
    cache_policy_id                = local.cache_policies.disabled
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security_headers.id
    viewer_protocol_policy         = "redirect-to-https"
    compress                       = true
  }

  # No cache for config.json (runtime configuration)
  ordered_cache_behavior {
    path_pattern               = "config/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # No cache for MFE remote entry points (Native Federation)
  ordered_cache_behavior {
    path_pattern               = "mfe-bundles/*/remoteEntry.json"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # Cache MFE static assets for 1 year
  ordered_cache_behavior {
    path_pattern               = "assets/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # No cache for Shell Module Federation entry point
  ordered_cache_behavior {
    path_pattern               = "remoteEntry.json"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # Cache JavaScript files for 1 year
  ordered_cache_behavior {
    path_pattern               = "*.js"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # Cache CSS files for 1 year
  ordered_cache_behavior {
    path_pattern               = "*.css"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  # Handle SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.has_certificate
    acm_certificate_arn            = local.has_certificate ? var.certificate_arn : null
    ssl_support_method             = local.has_certificate ? "sni-only" : null
    minimum_protocol_version       = local.has_certificate ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(local.common_tags, {
    Description = "CloudFront distribution for Angular MFE global delivery"
  })
}

# Green Environment CloudFront Distribution
resource "aws_cloudfront_distribution" "mfe_distribution_green" {
  count = local.enable_blue_green ? 1 : 0
  
  origin {
    domain_name              = aws_s3_bucket.mfe_bucket_green[0].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.mfe_oac.id
    origin_id                = "${var.project_name}-s3-origin-green"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CDN for ${var.project_name} ${var.environment}-green MFE"
  
  price_class = local.environment_config.price_class
  aliases     = local.has_custom_domain ? ["green.${var.domain_name}"] : []

  default_cache_behavior {
    allowed_methods                = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "${var.project_name}-s3-origin-green"
    cache_policy_id                = local.cache_policies.disabled
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security_headers.id
    viewer_protocol_policy         = "redirect-to-https"
    compress                       = true
  }

  ordered_cache_behavior {
    path_pattern               = "remoteEntry.json"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  ordered_cache_behavior {
    path_pattern               = "mfe-bundles/*/remoteEntry.json"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  ordered_cache_behavior {
    path_pattern               = "config/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.disabled
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  ordered_cache_behavior {
    path_pattern               = "assets/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  ordered_cache_behavior {
    path_pattern               = "*.js"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  ordered_cache_behavior {
    path_pattern               = "*.css"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "${var.project_name}-s3-origin-green"
    cache_policy_id            = local.cache_policies.optimized
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.has_certificate
    acm_certificate_arn            = local.has_certificate ? var.certificate_arn : null
    ssl_support_method             = local.has_certificate ? "sni-only" : null
    minimum_protocol_version       = local.has_certificate ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(local.common_tags, {
    Description = "Green environment CloudFront distribution for blue-green deployment"
    Environment = "${var.environment}-green"
  })
}