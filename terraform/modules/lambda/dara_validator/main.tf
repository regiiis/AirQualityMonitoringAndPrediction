#################################################
# DATA VALIDATOR LAMBDA
#################################################
resource "aws_lambda_function" "data_validator" {
  function_name                  = var.function_name
  handler                        = "data_validator.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.data_validator_role.arn
  timeout                        = 10
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Package the code directly from the file system
  filename         = "${path.root}/lambda/data_validator.zip"
  source_code_hash = filebase64sha256("${path.root}/lambda/data_validator.zip")

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn

  environment {
    variables = {
      SENSOR_DATA_STORAGE_S3 = var.storer_function_name
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
resource "aws_iam_role" "data_validator_role" {
  name = "data_validator_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

# Basic Lambda execution policy for logging
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.data_validator_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

# X-Ray tracing
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.data_validator_role.name
  policy_arn = "arn:aws:iam::aws:policy:AWSXRayDaemonWriteAccess"
}

# Lambda invoke permissions
resource "aws_iam_policy" "lambda_invoke_policy" {
  name        = "lambda-invoke-policy"
  description = "Allow invoking other Lambda functions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Resource = var.storer_function_arn
      Effect   = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "validator_lambda_invoke" {
  role       = aws_iam_role.data_validator_role.name
  policy_arn = aws_iam_policy.lambda_invoke_policy.arn
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
  source_arn    = var.api_gateway_arn
}

#################################################
# CODE SIGNING CONFIGURATION
#################################################
resource "aws_signer_signing_profile" "signing_profile" {
  name_prefix = "DataValidatorProfile"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

resource "aws_signer_signing_job" "signing_job" {
  profile_name = aws_signer_signing_profile.signing_profile.name

  source {
    s3 {
      bucket  = split("/", var.zip_path)[0]
      key     = join("/", slice(split("/", var.zip_path), 1, length(split("/", var.zip_path))))
      version = "LATEST"
    }
  }

  destination {
    s3 {
      bucket = split("/", var.zip_path)[0]
      prefix = "signed-lambda-code/data_validator/"
    }
  }
}

resource "aws_lambda_code_signing_config" "signing_config" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.signing_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing configuration for data_validator Lambda"
}
