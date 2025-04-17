#################################################
# DATA STORER LAMBDA
#################################################
resource "aws_lambda_function" "data_storer" {
  function_name                  = var.function_name
  handler                        = "data_storer.handler"
  runtime                        = "python3.11"
  role                           = aws_iam_role.data_storer_role.arn
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 5

  # Use signed code
  s3_bucket        = aws_signer_signing_job.signing_job.signed_object[0].s3[0].bucket
  s3_key           = aws_signer_signing_job.signing_job.signed_object[0].s3[0].key
  source_code_hash = filebase64sha256(var.zip_path)

  # Apply code signing configuration
  code_signing_config_arn = aws_lambda_code_signing_config.signing_config.arn

  environment {
    variables = {
      S3_BUCKET_NAME = var.bucket_name
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
resource "aws_iam_role" "data_storer_role" {
  name = "data_storer_lambda_role"

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

# S3 write policy
resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3-write-policy"
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
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.data_storer_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# Basic Lambda execution policy for logging
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.data_storer_role.name
  policy_arn = "arn:aws:iam::aws:policy:service-role/AWSLambdaBasicExecutionRole"
}

#################################################
# CODE SIGNING CONFIGURATION
#################################################
resource "aws_signer_signing_profile" "signing_profile" {
  name_prefix = "DataStorerProfile"
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
      prefix = "signed-lambda-code/data_storer/"
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

  description = "Code signing configuration for data_storer Lambda"
}

# Permission for data_validator Lambda to invoke this Lambda
resource "aws_lambda_permission" "invoke_permission" {
  statement_id  = "AllowDataValidatorInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_storer.function_name
  principal     = "lambda.amazonaws.com"
  # The source_arn will be provided when creating from parent module
}
