###########################################################
# Run Once to create the state backend for Terraform
# Using S3 Object Lock
###########################################################

terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

#################################################
# S3 BUCKET WITH OBJECT LOCK FOR TERRAFORM STATE
#################################################
resource "aws_s3_bucket" "tf_state" {
  bucket = "airq-terraform-state-bucket"

  # Enable object lock for state locking
  object_lock_enabled = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name         = "airq-all-terraform-state-bucket"
    Environment  = "All"
    ResourceType = "Meta"
    Project      = "AirQualityMonitoring"
  }
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Object Lock Configuration
resource "aws_s3_bucket_object_lock_configuration" "tf_state_lock" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state_block" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tf_state_lifecycle" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

#################################################
# OUTPUTS
#################################################
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.arn
}

output "object_lock_enabled" {
  description = "Whether S3 Object Lock is enabled"
  value       = aws_s3_bucket.tf_state.object_lock_enabled
}
