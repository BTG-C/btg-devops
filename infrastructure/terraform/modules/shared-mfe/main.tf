# ==============================================================================
# BTG MFE Infrastructure - Reusable Terraform Module
# ==============================================================================
# This module creates S3 + CloudFront infrastructure for hosting MFEs
# Designed for multi-account deployment (separate dev/staging/prod AWS accounts)
#
# Usage:
#   module "mfe_infrastructure" {
#     source = "../../modules/shared-mfe"
#     
#     aws_region   = "us-east-1"
#     project_name = "btg"
#     environment  = "dev"
#     github_repo  = "BTG-C/btg-*-mfe"
#   }
# ==============================================================================

# No provider block here - providers configured in environment folders
# This makes the module reusable across different AWS accounts

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
