#################################################
# LAAMBDA CONFIGURATION
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.94"
    }
  }
}

#################################################
# LAMBDA FUNCTIONS
#################################################
# Validator Lambda - Processes and validates incoming API requests
resource "aws_lambda_function" "validator" {
  function_name                  = var.validator_function_name
  handler                        = "validator.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.lambda_role.arn
  timeout                        = 10
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Use signed code
  s3_bucket        = aws_signer_signing_job.validator_job.signed_object[0].s3[0].bucket
  s3_key           = aws_signer_signing_job.validator_job.signed_object[0].s3[0].key
  source_code_hash = filebase64sha256(var.validator_zip_path)

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.validator_signing_config.arn

  environment {
    variables = {
      STORAGE_FUNCTION_NAME = aws_lambda_function.storage.function_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

# Storage Lambda - Stores validated sensor data in S3
resource "aws_lambda_function" "storage" {
  function_name                  = var.storage_function_name
  handler                        = "storage.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.lambda_storage_role.arn
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Use signed code
  s3_bucket        = aws_signer_signing_job.storage_job.signed_object[0].s3[0].bucket
  s3_key           = aws_signer_signing_job.storage_job.signed_object[0].s3[0].key
  source_code_hash = filebase64sha256(var.storage_zip_path)

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.storage_signing_config.arn

  environment {
    variables = {
      S3_BUCKET_NAME = var.storage_bucket_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

#################################################
# IAM ROLES AND POLICIES
#################################################
# IAM role for validator Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "validator_lambda_role"

  # Trust relationship policy allowing Lambda to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole" # Permission to assume this role
      Principal = {
        Service = "lambda.amazonaws.com" # AWS Lambda service
      }
      Effect = "Allow"
    }]
  })
}

# IAM role for storage Lambda function with S3 write permissions
resource "aws_iam_role" "lambda_storage_role" {
  name = "storage_lambda_role"

  # Trust relationship policy allowing Lambda to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole" # Permission to assume this role
      Principal = {
        Service = "lambda.amazonaws.com" # AWS Lambda service
      }
      Effect = "Allow"
    }]
  })
}

#################################################
# IAM POLICIES
#################################################
# S3 write policy for storage Lambda function
resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3-write-policy"
  description = "Allow writing to S3 bucket"

  # Specific permissions to write objects to S3
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:PutObject",   # Permission to create objects
        "s3:PutObjectAcl" # Permission to set object ACLs
      ]
      Resource = "arn:aws:s3:::${var.storage_bucket_name}/*"
      Effect   = "Allow"
    }]
  })
}

# Attach the S3 write policy to the storage Lambda role
resource "aws_iam_role_policy_attachment" "storage_s3_policy_attachment" {
  role       = aws_iam_role.lambda_storage_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# Basic Lambda execution policy for logging (both functions)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "storage_basic_execution" {
  role       = aws_iam_role.lambda_storage_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy:AWSXRayDaemonWriteAccess"
}

#################################################
# LAMBDA PERMISSIONS
#################################################
# Permission for API Gateway to invoke validator Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator.function_name
  principal     = "apigateway.amazonaws.com"

  # Optional: Restrict to specific API Gateway ARN
  source_arn = var.api_gateway_execution_arn
}

# Permission for validator Lambda to invoke storage Lambda
resource "aws_lambda_permission" "validator_invoke_storage" {
  statement_id  = "AllowValidatorInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.storage.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = aws_lambda_function.validator.arn
}

#################################################
# CODE SIGNING CONFIGURATION
#################################################
# Create signing profile for the validator Lambda
resource "aws_signer_signing_profile" "validator_profile" {
  name_prefix = "ValidatorProfile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Create signing profile for the storage Lambda
resource "aws_signer_signing_profile" "storage_profile" {
  name_prefix = "StorageProfile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Create signing job for validator Lambda code
resource "aws_signer_signing_job" "validator_job" {
  profile_name = aws_signer_signing_profile.validator_profile.name

  source {
    s3 {
      bucket  = split("/", var.validator_zip_path)[0]
      key     = join("/", slice(split("/", var.validator_zip_path), 1, length(split("/", var.validator_zip_path))))
      version = "LATEST"
    }
  }

  destination {
    s3 {
      bucket = split("/", var.validator_zip_path)[0]
      prefix = "signed-lambda-code/validator/"
    }
  }
}

# Create signing job for storage Lambda code
resource "aws_signer_signing_job" "storage_job" {
  profile_name = aws_signer_signing_profile.storage_profile.name

  source {
    s3 {
      bucket  = split("/", var.storage_zip_path)[0]
      key     = join("/", slice(split("/", var.storage_zip_path), 1, length(split("/", var.storage_zip_path))))
      version = "LATEST"
    }
  }

  destination {
    s3 {
      bucket = split("/", var.storage_zip_path)[0]
      prefix = "signed-lambda-code/storage/"
    }
  }
}

# Create code signing config for validator Lambda
resource "aws_lambda_code_signing_config" "validator_signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.validator_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for validator Lambda"
}

# Create code signing config for storage Lambda
resource "aws_lambda_code_signing_config" "storage_signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.storage_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for storage Lambda"
}
