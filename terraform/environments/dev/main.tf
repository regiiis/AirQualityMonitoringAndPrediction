#################################################
# DEV ENVIRONMENT CONFIGURATION
#################################################
# This file defines the infrastructure for the dev environment
# It provisions all AWS resources using the modules defined in the project

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
# PROVIDER CONFIGURATION
#################################################
provider "aws" {
  region = var.aws_region
}

#################################################
# NETWORK RESOURCES
#################################################
# Create VPC and networking components
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

#################################################
# STORAGE RESOURCES
#################################################
# Create S3 bucket for storing readings
module "database" {
  source = "../../modules/database"

  bucket_name = var.bucket_name
  environment = var.environment
}

#################################################
# COMPUTE RESOURCES
#################################################
# Create Lambda functions for processing data
module "lambda" {
  source = "../../modules/lambda"

  data_validator_function_name   = var.data_validator_function_name
  data_validator_zip_path        = var.data_validator_zip_path
  data_storer_function_name     = var.data_storer_function_name
  data_storer_zip_path          = var.data_storer_zip_path
  data_storer_bucket_name       = module.database.bucket_name
  api_gateway_execution_arn = "${module.api_gateway.api_gateway_arn}/*"
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_id         = module.vpc.lambda_security_group_id

  depends_on = [module.database, module.vpc]
}

#################################################
# API RESOURCES
#################################################
# Create API Gateway for receiving data from ESP32 devices
module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name                    = var.api_name
  data_validator_lambda_invoke_arn = module.lambda.data_validator_function_arn
}
