# Get your AWS account ID
data "aws_caller_identity" "current" {}

# Import blocks for existing resources
# import {
#   to = module.lambda.aws_s3_bucket.lambda_deployments
#   id = "${var.environment}-lambda-deployments"
# }

# import {
#   to = module.lambda.module.data_ingestion.aws_iam_policy.s3_write_policy
#   id = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.environment}-s3-write-policy"
# }

#################################################
# DEV ENVIRONMENT CONFIGURATION
#################################################
# This file defines the infrastructure for the dev environment
# It provisions all AWS resources using the modules defined in the project

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.57.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}


#################################################
# VPC
#################################################
# Create VPC and networking components
module "vpc" {
  source               = "../../modules/vpc"                          # Path to VPC module
  environment          = var.environment                              # Dev, staging, or prod
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"] # Use 2 AZs for redundancy
  vpc_cidr             = var.vpc_cidr                                 # IP address range for VPC
  private_subnet_cidrs = var.private_subnet_cidrs                     # IP ranges for private subnets (Lambda)
  public_subnet_cidrs  = var.public_subnet_cidrs                      # IP ranges for public subnets (NAT Gateway)
  tags                 = var.tags
}

#################################################
# DATABASE
#################################################
# Create S3 bucket for storing readings
module "database" {
  source      = "../../modules/database"
  bucket_name = "${var.environment}-${var.bucket_name}"
  environment = var.environment
  tags        = var.tags
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
  tags                         = var.tags
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
  tags                             = var.tags
}
