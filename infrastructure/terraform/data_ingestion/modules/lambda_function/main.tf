#################################################
# LAMBDA FUNCTION - MAIN
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10.0"
    }
  }
}

#################################################
# DATA INGESTION LAMBDA MODULE
#################################################
module "data_ingestion" {
  source            = "./data_ingestion"
  resource_prefix   = var.resource_prefix
  function_name     = "${var.resource_prefix}-data-ingestion"
  bucket_name       = var.data_ingestion_bucket_name
  subnet_ids        = var.subnet_ids
  security_group_id = var.security_group_id
  api_gateway_arn   = var.api_gateway_execution_arn
  environment       = var.environment

  # Pass the correct S3 bucket and key
  zip_s3_bucket  = aws_s3_bucket.lambda_deployments.id
  zip_s3_key     = aws_s3_object.data_ingestion_zip.key
  zip_s3_version = "LATEST" # Add this line to pass the version parameter

  signed_code_s3_bucket = aws_s3_bucket.lambda_deployments.id
  signed_code_s3_prefix = "signed"

  # Make this module depend on the S3 object upload
  depends_on = [aws_s3_object.data_ingestion_zip]
}

#################################################
# LAMBDA CODE PACKAGING
#################################################

resource "aws_s3_object" "data_ingestion_zip" {
  bucket      = aws_s3_bucket.lambda_deployments.id
  key         = "lambda/data_ingestion.zip"
  source      = var.data_ingestion_zip_path
  source_hash = uuid() # or base64sha256(file(var.data_ingestion_zip_path))
  tags        = merge(
    { Name = "${var.resource_prefix}-data-ingestion-zip" },
    var.tags
  )
}

#################################################
# LOGGING CONFIGURATION
#################################################
resource "aws_cloudwatch_log_group" "data_ingestion_logs" {
  name              = "/aws/lambda/${var.data_ingestion_function_name}"
  retention_in_days = 14

  tags = merge(
    {
      Name = "${var.environment}-data-ingestion-lambda-logs"
    },
    var.tags
  )
}
