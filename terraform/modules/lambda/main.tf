# terraform/modules/lambda/main.tf
#################################################
# LAMBDA FUNCTIONS
#################################################
# Validator Lambda - Processes and validates incoming API requests
resource "aws_lambda_function" "validator" {
  function_name = var.validator_function_name
  handler       = "validator.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn

  filename      = var.validator_zip_path  # Path to ZIP deployment package
  source_code_hash = filebase64sha256(var.validator_zip_path)  # Triggers updates when code changes

  # Configure Lambda environment variables for cross-service communication
  environment {
    variables = {
      STORAGE_FUNCTION_NAME = aws_lambda_function.storage.function_name
    }
  }

  # Configure Lambda timeouts and memory
  timeout     = 10  # Maximum execution time in seconds
  memory_size = 128  # Memory allocation in MB
}

# Storage Lambda - Stores validated sensor data in S3
resource "aws_lambda_function" "storage" {
  function_name = var.storage_function_name
  handler       = "storage.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_storage_role.arn

  filename      = var.storage_zip_path  # Path to ZIP deployment package
  source_code_hash = filebase64sha256(var.storage_zip_path)  # Triggers updates when code changes

  # Configure Lambda environment variables for S3 access
  environment {
    variables = {
      S3_BUCKET_NAME = var.storage_bucket_name
    }
  }

  # Configure Lambda timeouts and memory
  timeout     = 30  # Longer timeout for storage operations
  memory_size = 128  # Memory allocation in MB
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
      Action = "sts:AssumeRole"  # Permission to assume this role
      Principal = {
        Service = "lambda.amazonaws.com"  # AWS Lambda service
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
      Action = "sts:AssumeRole"  # Permission to assume this role
      Principal = {
        Service = "lambda.amazonaws.com"  # AWS Lambda service
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
        "s3:PutObject",        # Permission to create objects
        "s3:PutObjectAcl"      # Permission to set object ACLs
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
