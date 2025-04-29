# Get your AWS account ID
data "aws_caller_identity" "current" {}

#################################################
# LAMBDA FUNCTION - HANDLER
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider source
      version = "~> 5.0"        # Any 5.x version
    }
  }
}

#################################################
# DATA INGESTION LAMBDA
#################################################
resource "aws_lambda_function" "data_ingestion" {
  # Basic Lambda configuration for the main data ingestion function
  function_name                  = var.function_name
  handler                        = "data_ingestion.handler"             # Entry point for execution
  runtime                        = "python3.11"                         # Python runtime version
  role                           = aws_iam_role.data_ingestion_role.arn # Execution role
  timeout                        = 30                                   # Max execution time in seconds
  memory_size                    = 128                                  # Memory allocation in MB
  reserved_concurrent_executions = 5                                    # Limits concurrent executions

  # Use signed code for enhanced security
  s3_bucket        = aws_signer_signing_job.signing_job.signed_object[0].s3[0].bucket # Bucket with signed code
  s3_key           = aws_signer_signing_job.signing_job.signed_object[0].s3[0].key    # Object key for signed code
  source_code_hash = data.aws_s3_object.lambda_zip_metadata.etag                      # Hash from S3 metadata

  # Apply code signing config to ensure only trusted code runs
  code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn

  environment {
    variables = {
      SENSOR_DATA_STORAGE_S3 = var.bucket_name # S3 bucket where sensor data will be stored
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids          # VPC subnets for network isolation
    security_group_ids = [var.security_group_id] # Security group for network access control
  }
  tags = merge(
    {
      Name        = var.function_name
    },
    var.tags
  )
}

# Get metadata for the Lambda zip to detect changes
data "aws_s3_object" "lambda_zip_metadata" {
  bucket = var.zip_s3_bucket
  key    = var.zip_s3_key
}

###############################################
# IAM ROLES AND POLICIES
#################################################
resource "aws_iam_role" "data_ingestion_role" {
  # IAM role that Lambda assumes when executing
  name = "${lower(var.environment)}-data-ingestion-lambda-role"

  assume_role_policy = jsonencode({ # Trust policy defining who can assume this role
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com" # Allow Lambda service to assume this role
      }
      Effect = "Allow"
    }]
  })

  tags = merge(
    {
      Name        = "${var.function_name}-role"
    },
    var.tags
  )
}

# Basic Lambda execution policy for CloudWatch logging
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.data_ingestion_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" # Allows writing to CloudWatch logs
}

# X-Ray tracing policy for distributed tracing
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.data_ingestion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess" # Allows sending traces to X-Ray
}

# Custom S3 write policy for storing sensor data
resource "aws_iam_policy" "s3_write_policy" {
  name        = "${var.environment}-s3-write-policy"
  description = "Allow writing to S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ]
      Resource = "arn:aws:s3:::${var.bucket_name}/*"
      Effect   = "Allow"
    }]
  })
  tags = merge(
    {
      Name = "${var.function_name}-s3-write-policy"
    },
    var.tags
  )
}

# Attach the S3 write policy to the Lambda role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.data_ingestion_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn # Links custom S3 policy to role
}

#################################################
# LAMBDA PERMISSIONS
#################################################
# Permission for API Gateway to invoke this Lambda function
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction" # Permission to invoke this function
  function_name = aws_lambda_function.data_ingestion.function_name
  principal     = "apigateway.amazonaws.com" # API Gateway service can invoke
  source_arn    = var.api_gateway_arn        # Source API Gateway ARN
}

#################################################
# CODE SIGNING CONFIGURATION
#################################################
# Create a signing profile for digitally signing Lambda code
resource "aws_signer_signing_profile" "signing_profile" {
  name_prefix = "DataIngestionProfile"   # Prefix for the profile name
  platform_id = "AWSLambda-SHA384-ECDSA" # Signing algorithm and platform

  tags = merge(
    {
      Name        = "${var.function_name}-signing-profile"
    },
    var.tags
  )
}

# Create a signing job to sign the Lambda deployment package
resource "aws_signer_signing_job" "signing_job" {
  profile_name = aws_signer_signing_profile.signing_profile.name

  # Source code location to sign - using explicit bucket and key
  source {
    s3 {
      bucket  = var.zip_s3_bucket
      key     = var.zip_s3_key
      version = "LATEST"
    }
  }

  # Destination for the signed code
  destination {
    s3 {
      bucket = var.signed_code_s3_bucket
      prefix = var.signed_code_s3_prefix
    }
  }

  # Make sure the signing job depends on the zip file upload
  depends_on = [data.aws_s3_object.lambda_zip_metadata]
}

# Define code signing configuration for Lambda
resource "aws_lambda_code_signing_config" "signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.signing_profile.version_arn] # Trusted signer
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce" # Reject unsigned code
  }

  description = "Code signing configuration for data_ingestion Lambda"
  tags = merge(
    {
      Name        = "${var.function_name}-signing-config"
    },
    var.tags
  )
}
