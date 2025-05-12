#################################################
# LAMBDA DEPLOYMENT BUCKET
#################################################

# Create bucket specifically for Lambda deployments
resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "${var.resource_prefix}-lambda-deployments"

  # Comment out object lock for now
  # object_lock_enabled = true

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      bucket
    ]
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-lambda-deployments"
    },
    var.tags
  )
}

resource "aws_s3_bucket_versioning" "lambda_deployments_versioning" {
  bucket = aws_s3_bucket.lambda_deployments.id
  versioning_configuration {
    status = "Enabled"
  }
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

# Add a bucket policy allowing AWS Signer to read objects
resource "aws_s3_bucket_policy" "lambda_deployments_signer_access" {
  bucket = aws_s3_bucket.lambda_deployments.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "signer.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.lambda_deployments.arn}/*"
        ]
      }
    ]
  })

  # Apply this policy after versioning is enabled
  depends_on = [aws_s3_bucket_versioning.lambda_deployments_versioning]
}
