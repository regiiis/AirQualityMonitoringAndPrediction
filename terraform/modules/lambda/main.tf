#################################################
# TERRAFORM CONFIGURATION
#################################################
terraform {
  required_version = ">= 1.11.4"                  # Minimum Terraform version required

  required_providers {
    aws = {
      source  = "hashicorp/aws"                   # AWS provider source
      version = ">= 5.94"                         # Minimum AWS provider version
    }
  }
}

#################################################
# DATA INGESTION LAMBDA MODULE
#################################################
module "data_ingestion" {
  source = "./data_ingestion"                     # Path to module directory

  # Required parameters for the module
  function_name = var.data_ingestion_function_name # Lambda function name
  zip_path = var.data_ingestion_zip_path          # Path to deployment package
  bucket_name = var.data_ingestion_bucket_name    # S3 bucket for data storage
  subnet_ids = var.subnet_ids                     # VPC subnets for Lambda
  security_group_id = var.security_group_id       # Security group for Lambda
  api_gateway_arn = var.api_gateway_execution_arn # API Gateway that invokes Lambda
}

#################################################
# LAMBDA CODE PACKAGING
#################################################
resource "null_resource" "lambda_zip" {
  triggers = {
    # Re-run when the source code changes
    data_ingestion_code_hash = filemd5("${path.root}/app/handlers/data_ingestion/data_ingestion.py")
  }

  # Create zip package for Lambda deployment
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.root}/lambda              # Ensure directory exists
      cd ${path.root}/app/handlers              # Change to handlers directory
      zip -j ${path.root}/lambda/data_ingestion.zip data_ingestion.py  # Create deployment package
    EOT
  }
}

#################################################
# LOGGING CONFIGURATION
#################################################
# Keep CloudWatch Log Groups in main module
resource "aws_cloudwatch_log_group" "data_ingestion_logs" {
  name              = "/aws/lambda/${var.data_ingestion_function_name}"  # Standard Lambda log group naming
  retention_in_days = 14                                                # Log retention policy
}
