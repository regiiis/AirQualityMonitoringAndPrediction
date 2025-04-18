#################################################
# TERRAFORM CONFIGURATION
#################################################
terraform {
  required_version = ">= 1.11.4"                  # Minimum Terraform version required

  required_providers {
    aws = {
      source  = "hashicorp/aws"                   # AWS provider source
      version = ">= 5.94"                         # Minimum AWS provider version
    }
  }
}

#################################################
# S3 BUCKET CONFIGURATION
#################################################
resource "aws_s3_bucket" "readings_storage" {
  bucket = var.bucket_name                        # Bucket name from variables

  tags = {
    Name        = "${var.environment}-air-quality-readings"  # Resource identification tag
    Environment = var.environment                # Environment tag for resource grouping
    Project     = "AirQualityMonitoring"         # Project tag for cost tracking
  }
}

#################################################
# BUCKET SECURITY CONFIGURATION
#################################################
# Block ALL public access - critical for data security
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.readings_storage.id      # Reference to bucket ID

  block_public_acls       = true                  # Prevents public ACLs from being applied
  block_public_policy     = true                  # Prevents public bucket policies
  ignore_public_acls      = true                  # Ignores any public ACLs
  restrict_public_buckets = true                  # Restricts access to bucket with public policies
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "readings_encryption" {
  bucket = aws_s3_bucket.readings_storage.id      # Reference to bucket ID

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"                    # AES-256 encryption for data at rest
    }
  }
}

# Enable bucket versioning for data protection and recovery
resource "aws_s3_bucket_versioning" "readings_versioning" {
  bucket = aws_s3_bucket.readings_storage.id      # Reference to bucket ID
  versioning_configuration {
    status = "Enabled"                            # Keep previous versions of objects
  }
}

#################################################
# DATA LIFECYCLE MANAGEMENT
#################################################
# Configure lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "readings_lifecycle" {
  bucket = aws_s3_bucket.readings_storage.id      # Reference to bucket ID

  # Rule to expire old object versions to reduce storage costs
  rule {
    id     = "expire-old-versions"                # Unique identifier for the rule
    status = "Enabled"                            # Rule is active

    filter {
      prefix = ""                                 # Empty prefix means "apply to all objects"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30                        # Delete previous versions after 30 days
    }
  }

  # Rule to transition infrequently accessed data to cheaper storage
  rule {
    id     = "archive-old-data"                   # Unique identifier for the rule
    status = "Enabled"                            # Rule is active

    filter {
      prefix = ""                                 # Empty prefix means "apply to all objects"
    }

    # Move older data to infrequent access after 90 days
    transition {
      days          = 90                          # Time before transition
      storage_class = "STANDARD_IA"               # Infrequent Access tier (cheaper)
    }

    # Archive to Glacier after 365 days for long-term retention
    transition {
      days          = 365                         # Time before transition
      storage_class = "GLACIER"                   # Cold storage tier (much cheaper)
    }
  }

  # Cleanup rule for incomplete multipart uploads to prevent storage waste
  rule {
    id     = "readings-cleanup"                   # Unique identifier for the rule
    status = "Enabled"                            # Rule is active

    abort_incomplete_multipart_upload {
      days_after_initiation = 7                   # Cleanup unfinished uploads after 7 days
    }

    filter {
      prefix = "readings/"                        # Apply only to the readings folder
    }
  }
}
