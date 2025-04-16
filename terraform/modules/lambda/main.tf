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
# Data Validator Lambda - Processes and validates incoming API requests
resource "aws_lambda_function" "data_validator" {
  function_name                  = var.data_validator_function_name
  handler                        = "data_validator.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.data_validator_role.arn
  timeout                        = 10
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Package the code directly from the file system
  filename         = "${path.root}/app/handlers/data_validator.py.zip"
  source_code_hash = filebase64sha256("${path.root}/app/handlers/data_validator.py")

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.data_validator_signing_config.arn

  environment {
    variables = {
      DATA_STORAGE_FUNCTION_NAME = aws_lambda_function.data_storer.function_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

# Data Storage Lambda - Stores validated sensor data in S3
resource "aws_lambda_function" "data_storer" {
  function_name                  = var.data_storer_function_name
  handler                        = "data_storer.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.data_storer_role.arn
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Use signed code
  s3_bucket        = aws_signer_signing_job.data_storer_job.signed_object[0].s3[0].bucket
  s3_key           = aws_signer_signing_job.data_storer_job.signed_object[0].s3[0].key
  source_code_hash = filebase64sha256(var.data_storer_zip_path)

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.data_storer_signing_config.arn

  environment {
    variables = {
      S3_BUCKET_NAME = var.data_storer_bucket_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

# Define a null_resource to zip the Python files on demand
resource "null_resource" "lambda_zip" {
  triggers = {
    data_validator_code_hash = filemd5("${path.root}/app/handlers/data_validator.py")
    data_storer_code_hash   = filemd5("${path.root}/app/handlers/data_storer.py")
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.root}/lambda
      cd ${path.root}/app/handlers
      zip -j ${path.root}/lambda/data_validator.zip data_validator.py
      zip -j ${path.root}/lambda/data_storer.zip data_storer.py
    EOT
  }
}

#################################################
# IAM ROLES AND POLICIES
#################################################
# IAM role for data_validator Lambda function
resource "aws_iam_role" "data_validator_role" {
  name = "data_validator_lambda_role"

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

# IAM role for data_storer Lambda function with S3 write permissions
resource "aws_iam_role" "data_storer_role" {
  name = "data_storer_lambda_role"

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
# S3 write policy for data_storer Lambda function
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
      Resource = "arn:aws:s3:::${var.data_storer_bucket_name}/*"
      Effect   = "Allow"
    }]
  })
}

# Attach the S3 write policy to the data_storer Lambda role
resource "aws_iam_role_policy_attachment" "data_storer_s3_policy_attachment" {
  role       = aws_iam_role.data_storer_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# Basic Lambda execution policy for logging (both functions)
resource "aws_iam_role_policy_attachment" "data_validator_basic_execution" {
  role       = aws_iam_role.data_validator_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "data_storer_basic_execution" {
  role       = aws_iam_role.data_storer_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "data_validator_xray" {
  role       = aws_iam_role.data_validator_role.name
  policy_arn = "arn:aws:iam::aws:policy:AWSXRayDaemonWriteAccess"
}

#################################################
# LAMBDA PERMISSIONS
#################################################
# Permission for API Gateway to invoke data_validator Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_validator.function_name
  principal     = "apigateway.amazonaws.com"

  # Optional: Restrict to specific API Gateway ARN
  source_arn = var.api_gateway_execution_arn
}

# Permission for data_validator Lambda to invoke data_storer Lambda
resource "aws_lambda_permission" "data_validator_invoke_storage" {
  statement_id  = "AllowDataValidatorInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_storer.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = aws_lambda_function.data_validator.arn
}

#################################################
# CODE SIGNING CONFIGURATION
#################################################
# Create signing profile for the data_validator Lambda
resource "aws_signer_signing_profile" "data_validator_profile" {
  name_prefix = "DataValidatorProfile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Create signing profile for the data_storer Lambda
resource "aws_signer_signing_profile" "data_storer_profile" {
  name_prefix = "DataStorerProfile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Create signing job for data_validator Lambda code
resource "aws_signer_signing_job" "data_validator_job" {
  profile_name = aws_signer_signing_profile.data_validator_profile.name

  source {
    s3 {
      bucket  = split("/", var.data_validator_zip_path)[0]
      key     = join("/", slice(split("/", var.data_validator_zip_path), 1, length(split("/", var.data_validator_zip_path))))
      version = "LATEST"
    }
  }

  destination {
    s3 {
      bucket = split("/", var.data_validator_zip_path)[0]
      prefix = "signed-lambda-code/data_validator/"
    }
  }
}

# Create signing job for data_storer Lambda code
resource "aws_signer_signing_job" "data_storer_job" {
  profile_name = aws_signer_signing_profile.data_storer_profile.name

  source {
    s3 {
      bucket  = split("/", var.data_storer_zip_path)[0]
      key     = join("/", slice(split("/", var.data_storer_zip_path), 1, length(split("/", var.data_storer_zip_path))))
      version = "LATEST"
    }
  }

  destination {
    s3 {
      bucket = split("/", var.data_storer_zip_path)[0]
      prefix = "signed-lambda-code/data_storer/"
    }
  }
}

# Create code signing config for data_validator Lambda
resource "aws_lambda_code_signing_config" "data_validator_signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.data_validator_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for data_validator Lambda"
}

# Create code signing config for data_storer Lambda
resource "aws_lambda_code_signing_config" "data_storer_signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.data_storer_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for data_storer Lambda"
}

resource "aws_cloudwatch_log_group" "data_validator_logs" {
  name              = "/aws/lambda/${var.data_validator_function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "data_storer_logs" {
  name              = "/aws/lambda/${var.data_storer_function_name}"
  retention_in_days = 14
}
