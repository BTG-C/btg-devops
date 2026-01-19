# ==============================================================================
# IAM ROLES AND POLICIES FOR GITHUB ACTIONS OIDC
# ==============================================================================

# IAM Role for GitHub Actions Deployment
resource "aws_iam_role" "github_actions_role" {
  name = "${var.project_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Description = "IAM role for GitHub Actions OIDC authentication and MFE deployment"
  })
}

# IAM Policy for S3 and CloudFront Permissions
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.project_name}-${var.environment}-deployment-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3 Permissions for Shell buckets
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = concat([
          aws_s3_bucket.mfe_bucket.arn,
          "${aws_s3_bucket.mfe_bucket.arn}/*",
        ], local.enable_blue_green ? [
          aws_s3_bucket.mfe_bucket_green[0].arn,
          "${aws_s3_bucket.mfe_bucket_green[0].arn}/*"
        ] : [])
      },
      {
        # CloudFront Permissions
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution"
        ]
        Resource = concat(
          [aws_cloudfront_distribution.blue_distribution.arn],
          local.enable_blue_green ? [aws_cloudfront_distribution.green_distribution[0].arn] : []
        )
      },
      {
        # CloudFront List Permission (requires wildcard per AWS API)
        Effect = "Allow"
        Action = [
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      },
      {
        # SSM Permissions for blue-green deployment
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}