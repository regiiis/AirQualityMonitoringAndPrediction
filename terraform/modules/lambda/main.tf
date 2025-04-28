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
  source            = "./data_ingestion"
  function_name     = var.data_ingestion_function_name
  zip_s3_bucket     = aws_s3_bucket.lambda_deployments.id
  zip_s3_key        = aws_s3_object.data_ingestion_zip.key
  bucket_name       = var.data_ingestion_bucket_name
  subnet_ids        = var.subnet_ids
  security_group_id = var.security_group_id
  api_gateway_arn   = var.api_gateway_execution_arn
}

#################################################
# LAMBDA CODE PACKAGING
#################################################
resource "null_resource" "lambda_zip" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = <<EOT
      mkdir -p $(dirname ${var.data_ingestion_zip_path})
      cd ${path.module}/../../app/handlers
      zip -j ${var.data_ingestion_zip_path} data_ingestion/data_ingestion.py || echo "Warning: Zip failed, but continuing..."
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "aws_s3_object" "data_ingestion_zip" {
  bucket     = aws_s3_bucket.lambda_deployments.id
  key        = "lambda/data_ingestion.zip"
  source     = var.data_ingestion_zip_path
  etag       = filemd5(var.data_ingestion_zip_path)
  depends_on = [null_resource.lambda_zip]
}

#################################################
# LOGGING CONFIGURATION
#################################################
resource "aws_cloudwatch_log_group" "data_ingestion_logs" {
  name              = "/aws/lambda/${var.data_ingestion_function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.environment}-data-ingestion-lambda-logs"
  }
}
