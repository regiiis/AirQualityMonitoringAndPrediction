#################################################
# LAMBDA DEPLOYMENT BUCKET
#################################################

# Create bucket specifically for Lambda deployments
resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "${var.environment}-lambda-deployments-bucket"

  object_lock_enabled = true
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      bucket  # Prevents recreation attempts if bucket exists
    ]
  }

  tags = merge(
    {
      Name = "${var.environment}-lambda-deployments"
    },
    var.tags
  )
}

#################################################
# BUCKET SECURITY CONFIGURATION
#################################################
# Block public access
resource "aws_s3_bucket_public_access_block" "lambda_deployment_block_public" {
  bucket = aws_s3_bucket.lambda_deployments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_deployment_encryption" {
  bucket = aws_s3_bucket.lambda_deployments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#################################################
# DATA LIFECYCLE MANAGEMENT
#################################################
resource "aws_s3_bucket_lifecycle_configuration" "lambda_deployments_lifecycle" {
  bucket = aws_s3_bucket.lambda_deployments.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    # Add this filter block to fix the validation error
    filter {
      prefix = "lambda/"
    }

    expiration {
      days = 90 # Keep deployments for 90 days for rollback capability
    }

    noncurrent_version_expiration {
      noncurrent_days = 7 # Remove old versions after a week
    }
  }
}
