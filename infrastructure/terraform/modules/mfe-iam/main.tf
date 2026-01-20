# ==============================================================================
# MFE IAM Module - GitHub Actions OIDC
# ==============================================================================
# Purpose: IAM role for GitHub Actions to deploy MFEs to S3 and invalidate CloudFront
# ==============================================================================

# Check if GitHub OIDC provider already exists
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions-mfe"

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions-mfe"
    Environment = var.environment
    Purpose     = "MFE Deployment"
  }
}

# IAM Policy for S3 and CloudFront
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "mfe-deployment-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution"
        ]
        Resource = var.cloudfront_distribution_arn
      },
      {
        Sid    = "CloudFrontList"
        Effect = "Allow"
        Action = [
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      }
    ]
  })
}
