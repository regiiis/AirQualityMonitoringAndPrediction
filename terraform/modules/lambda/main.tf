#################################################
# TERRAFORM CONFIGURATION
#################################################
terraform {
  required_version = ">= 1.11.4" # Minimum Terraform version required

  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider source
      version = "~> 5.0"        # Any 5.x version
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

#################################################
# DATA INGESTION LAMBDA MODULE
#################################################
module "data_ingestion" {
  source            = "./data_ingestion"                   # Path to module directory
  function_name     = var.data_ingestion_function_name     # Lambda function name
  zip_s3_bucket     = aws_s3_bucket.lambda_deployments.id  # Pass bucket name
  zip_s3_key        = aws_s3_object.data_ingestion_zip.key # Pass object key
  bucket_name       = var.data_ingestion_bucket_name       # S3 bucket for data storage
  subnet_ids        = var.subnet_ids                       # VPC subnets for Lambda
  security_group_id = var.security_group_id                # Security group for Lambda
  api_gateway_arn   = var.api_gateway_execution_arn        # API Gateway that invokes Lambda
}

#################################################
# LAMBDA CODE PACKAGING
#################################################
# Keep the null_resource for local ZIP creation
resource "null_resource" "lambda_zip" {
  triggers = {
    data_ingestion_code_hash = filemd5("${path.root}/app/handlers/data_ingestion/data_ingestion.py")
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.root}/lambda
      cd ${path.root}/app/handlers
      zip -j ${path.root}/lambda/data_ingestion.zip data_ingestion/data_ingestion.py
    EOT
  }
}

# Add S3 upload resource - let Terraform handle it
resource "aws_s3_object" "data_ingestion_zip" {
  bucket = aws_s3_bucket.lambda_deployments.id
  key    = "lambda/data_ingestion.zip"
  source = "${path.root}/lambda/data_ingestion.zip"
  etag   = filemd5("${path.root}/lambda/data_ingestion.zip")

  depends_on = [null_resource.lambda_zip]

  tags = {
    Name = "${var.environment}-data-ingestion-lambda-zip"
  }
}

#################################################
# LOGGING CONFIGURATION
#################################################
# Keep CloudWatch Log Groups in main module
resource "aws_cloudwatch_log_group" "data_ingestion_logs" {
  name              = "/aws/lambda/${var.data_ingestion_function_name}" # Standard Lambda log group naming
  retention_in_days = 14                                                # Log retention policy

  tags = {
    Name = "${var.environment}-data-ingestion-lambda-logs"
  }
}
