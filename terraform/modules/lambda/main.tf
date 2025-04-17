#################################################
# TERRAFORM CONFIGURATION
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
module "data_validator" {
  source = "./data_validator"

  function_name     = var.data_validator_function_name
  zip_path          = var.data_validator_zip_path
  subnet_ids        = var.subnet_ids
  security_group_id = var.security_group_id
  api_gateway_arn   = var.api_gateway_execution_arn
  storer_function_arn = module.data_storer.function_arn
  storer_function_name = module.data_storer.function_name
}

module "data_storer" {
  source = "./data_storer"

  function_name     = var.data_storer_function_name
  zip_path          = var.data_storer_zip_path
  bucket_name       = var.data_storer_bucket_name
  subnet_ids        = var.subnet_ids
  security_group_id = var.security_group_id
}

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

# Keep CloudWatch Log Groups in main module
resource "aws_cloudwatch_log_group" "data_validator_logs" {
  name              = "/aws/lambda/${var.data_validator_function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "data_storer_logs" {
  name              = "/aws/lambda/${var.data_storer_function_name}"
  retention_in_days = 14
}
