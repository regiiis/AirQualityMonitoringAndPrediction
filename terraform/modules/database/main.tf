#################################################
# S3 BUCKET CONFIGURATION
#################################################
resource "aws_s3_bucket" "readings_storage" {
  bucket = var.bucket_name

  tags = {
    Name        = "${var.environment}-air-quality-readings"
    Environment = var.environment
    Project     = "AirQualityMonitoring"
  }
}

#################################################
# BUCKET SECURITY CONFIGURATION
#################################################
# Block ALL public access - critical for data security
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.readings_storage.id

  block_public_acls       = true  # Prevents public ACLs from being applied
  block_public_policy     = true  # Prevents public bucket policies
  ignore_public_acls      = true  # Ignores any public ACLs
  restrict_public_buckets = true  # Restricts access to bucket with public policies
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

# Disable bucket versioning - not needed for sensor data
resource "aws_s3_bucket_versioning" "readings_versioning" {
  bucket = aws_s3_bucket.readings_storage.id
  versioning_configuration {
    status = "Disabled"
  }
}

#################################################
# DATA LIFECYCLE MANAGEMENT
#################################################
# Configure lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "readings_lifecycle" {
  bucket = aws_s3_bucket.readings_storage.id

  rule {
    id      = "archive-old-data"
    status  = "Enabled"

    # Move older data to infrequent access after 90 days
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    # Archive to Glacier after 365 days
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

  # Create partitions by date prefix
  rule {
    id     = "readings-cleanup"
    status = "Enabled"

    filter {
      prefix = "readings/"  # Apply only to the readings folder
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
