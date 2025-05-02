# Get metadata for the Lambda zip to detect changes
data "aws_s3_object" "lambda_zip_metadata" {
  bucket = var.zip_s3_bucket
  key    = var.zip_s3_key
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
  # reserved_concurrent_executions = 10                                    # Limits concurrent executions

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
      Name = "${var.resource_prefix}-${var.function_name}"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }

  # Add this depends_on block to ensure IAM permissions are fully propagated
  depends_on = [time_sleep.iam_propagation]
}

###############################################
# IAM ROLES AND POLICIES
#################################################
resource "aws_iam_role" "data_ingestion_role" {
  # IAM role that Lambda assumes when executing
  name = "${var.resource_prefix}-data-ingestion-lambda-role"

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
      Name = "${var.resource_prefix}-${var.function_name}-role"
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
  name        = "${var.resource_prefix}-s3-write-policy"
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
      Name = "${var.resource_prefix}-${var.function_name}-s3-write-policy"
    },
    var.tags
  )
}

# Attach the S3 write policy to the Lambda role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.data_ingestion_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn # Links custom S3 policy to role
}

# VPC networking permissions for Lambda
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.data_ingestion_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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
  name_prefix = "${replace(var.resource_prefix, "-", "")}DataIngestionProfile"
  platform_id = "AWSLambda-SHA384-ECDSA" # Signing algorithm and platform

  signature_validity_period {
    value = 135
    type  = "MONTHS"
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-${var.function_name}-signing-profile"
    },
    var.tags
  )
}

# Update signing job to use a specific source
resource "aws_signer_signing_job" "signing_job" {
  profile_name = aws_signer_signing_profile.signing_profile.name

  source {
    s3 {
      bucket  = var.zip_s3_bucket
      key     = var.zip_s3_key
      version = data.aws_s3_object.lambda_zip_metadata.version_id
    }
  }

  destination {
    s3 {
      bucket = var.signed_code_s3_bucket
      prefix = var.signed_code_s3_prefix
    }
  }

  depends_on = [
    data.aws_s3_object.lambda_zip_metadata,
    aws_signer_signing_profile.signing_profile
  ]
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
      Name = "${var.resource_prefix}-${var.function_name}-signing-config"
    },
    var.tags
  )
}

# Add this resource for IAM propagation delay
resource "time_sleep" "iam_propagation" {
  depends_on = [
    aws_iam_role_policy_attachment.vpc_access,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy_attachment.xray,
    aws_iam_role_policy_attachment.s3_policy_attachment
  ]

  create_duration = "10s"
}
