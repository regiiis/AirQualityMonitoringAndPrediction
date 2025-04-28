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

#################################################
# PROVIDER CONFIGURATION (AWS)
#################################################
provider "aws" {
  region = var.aws_region # Use AWS region from variables
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
  source = "../../modules/database" # Path to database module

  bucket_name = var.bucket_name # Name for S3 bucket storing sensor data
  environment = var.environment # Environment tag (dev)
}

#################################################
# LAMBDA FUNCTIONS
#################################################
# Create Lambda functions for processing data
module "lambda" {
  source                       = "../../modules/lambda"
  data_ingestion_function_name = var.data_ingestion_function_name
  data_ingestion_zip_path      = var.data_ingestion_zip_path
  data_ingestion_bucket_name   = module.database.bucket_name
  subnet_ids                   = module.vpc.private_subnet_ids
  security_group_id            = module.vpc.lambda_security_group_id
  environment                  = var.environment
  depends_on                   = [module.database, module.vpc]
}

#################################################
# API GATEWAY
#################################################
# Create API Gateway for receiving data from ESP32 devices
module "api_gateway" {
  source = "../../modules/api_gateway"

  # Add this line to fix the error:
  environment = var.environment # Or use "dev" directly

  # Your other parameters remain unchanged
  api_name                         = var.api_name
  data_validator_lambda_invoke_arn = module.lambda.data_ingestion_function_invoke_arn
}

#################################################
# OUTPUTS
#################################################
# These allow other Terraform configurations or CI/CD tools to reference this environment
# They also make key information available in the Terraform output after deployment
