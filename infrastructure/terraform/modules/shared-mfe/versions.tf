# ==============================================================================
# VERSIONS AND DEPENDENCIES
# ==============================================================================
# This file defines the Terraform and provider version constraints

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Add backend configuration here if using remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "angular-mfe/terraform.tfstate"
  #   region = "us-east-1"
  # }
}