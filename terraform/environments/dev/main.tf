#################################################
# DEV ENVIRONMENT CONFIGURATION
#################################################
# This file defines the infrastructure for the dev environment
# It provisions all AWS resources using the modules defined in the project

terraform {
  required_version = ">= 1.11.4" # Minimum Terraform version required

  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider source
      version = "~> 5.0"        # Any 5.x version
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

#################################################
# VPC
#################################################
# Create VPC and networking components
module "vpc" {
  source = "../../modules/vpc" # Path to VPC module
  environment          = var.environment                              # Dev, staging, or prod
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"] # Use 2 AZs for redundancy
  vpc_cidr             = var.vpc_cidr                                 # IP address range for VPC
  private_subnet_cidrs = var.private_subnet_cidrs                     # IP ranges for private subnets (Lambda)
  public_subnet_cidrs  = var.public_subnet_cidrs                      # IP ranges for public subnets (NAT Gateway)
}

#################################################
# DATABASE
#################################################
# Create S3 bucket for storing readings
module "database" {
  source = "../../modules/database"
  bucket_name = "${var.environment}-${var.bucket_name}"
  environment = var.environment
}

#################################################
# LAMBDA FUNCTIONS
#################################################
# Create Lambda functions for processing data
module "lambda" {
  source                       = "../../modules/lambda"
  data_ingestion_function_name = "${var.environment}-${var.data_ingestion_function_name}"
  data_ingestion_bucket_name   = "${var.environment}-${var.bucket_name}"
  data_ingestion_zip_path      = var.data_ingestion_zip_path
  subnet_ids                   = module.vpc.private_subnet_ids
  security_group_id            = module.vpc.lambda_security_group_id
  environment                  = var.environment
  api_gateway_execution_arn    = module.api_gateway.api_gateway_arn
  depends_on                   = [module.database, module.vpc]
}

#################################################
# API GATEWAY
#################################################
module "api_gateway" {
  source                           = "../../modules/api_gateway"
  api_name                         = "${var.environment}-${var.api_name}"
  api_key_name                     = "${var.environment}-esp32-device-key"
  usage_plan_name                  = "${var.environment}-esp32-usage-plan"
  log_group_name                   = "/aws/apigateway/${var.environment}-${var.api_name}"
  stage_name                       = "v1"
  environment                      = var.environment
  data_validator_lambda_invoke_arn = module.lambda.data_ingestion_function_invoke_arn
}
