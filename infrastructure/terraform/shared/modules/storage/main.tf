#################################################
# SHARED STORAGE MODULE
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#################################################
# S3 BUCKET FOR SENSOR DATA
#################################################
resource "aws_s3_bucket" "readings_storage" {
  bucket = "${var.resource_prefix}-${var.bucket_name}"

  object_lock_enabled = true
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      bucket
    ]
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-${var.bucket_name}"
      ResourceType = "SharedStorage"
    },
    var.tags
  )
}

#################################################
# BUCKET SECURITY CONFIGURATION
#################################################
# Block ALL public access - critical for data security
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.readings_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "readings_encryption" {
  bucket = aws_s3_bucket.readings_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable bucket versioning for data protection and recovery
resource "aws_s3_bucket_versioning" "readings_versioning" {
  bucket = aws_s3_bucket.readings_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

#################################################
# DATA LIFECYCLE MANAGEMENT
#################################################
resource "aws_s3_bucket_lifecycle_configuration" "readings_lifecycle" {
  bucket = aws_s3_bucket.readings_storage.id

  # Rule to expire old object versions to reduce storage costs
  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule to transition infrequently accessed data to cheaper storage
  rule {
    id     = "archive-old-data"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  # Cleanup rule for incomplete multipart uploads
  rule {
    id     = "readings-cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {
      prefix = "readings/"
    }
  }
}

# Export bucket information to SSM Parameter Store
resource "aws_ssm_parameter" "readings_bucket_name" {
  name  = "/shared/${var.environment}/storage/readings-bucket-name"
  type  = "String"
  value = aws_s3_bucket.readings_storage.id
  tags  = var.tags
}

resource "aws_ssm_parameter" "readings_bucket_arn" {
  name  = "/shared/${var.environment}/storage/readings-bucket-arn"
  type  = "String"
  value = aws_s3_bucket.readings_storage.arn
  tags  = var.tags
}
