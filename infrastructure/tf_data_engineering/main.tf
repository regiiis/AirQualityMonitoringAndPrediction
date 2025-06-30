#################################################
# TERRAFORM CONFIGURATION
#################################################
terraform {
  required_version = ">= 1.11.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "airq-terraform-state-bucket"
    region         = "eu-central-1"
    encrypt        = true
    use_lockfile   = true
  }
}

#################################################
# PROVIDER CONFIGURATION
#################################################
provider "aws" {
  region = var.aws_region
}

#################################################
# DATA SOURCES
#################################################
# VPC and networking parameters
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/${var.environment}/vpc/id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/${var.environment}/vpc/private-subnet-ids"
}

data "aws_ssm_parameter" "lambda_security_group_id" {
  name = "/shared/${var.environment}/vpc/lambda-sg-id"
}

# Storage parameters
data "aws_ssm_parameter" "readings_bucket_name" {
  name = "/shared/${var.environment}/storage/readings-bucket-name"
}

# API Gateway parameters
data "aws_ssm_parameter" "api_invoke_url" {
  name = "/shared/${var.environment}/api-gateway/invoke-url"
}

data "aws_ssm_parameter" "api_id" {
  name = "/shared/${var.environment}/api-gateway/id"
}

data "aws_ssm_parameter" "api_execution_arn" {
  name = "/shared/${var.environment}/api-gateway/execution-arn"
}

data "aws_ssm_parameter" "data_ingestion_resource_id" {
  name = "/shared/${var.environment}/api-gateway/data-ingestion-resource-id"
}

#################################################
# LOCAL VARIABLES
#################################################
locals {
  # Create a globally unique prefix for resources
  prefix = "${var.project_prefix}-${var.environment}"

  # Merge tags for data ingestion service
  tags = merge(
    var.common_tags,
    var.environment_tags,
    var.data_engineering_tags
  )
}

#################################################
# MODULES
#################################################
module "data_consolidation" {
  source = "./modules/data_consolidation"
  # General configuration - from common.tfvars
  resource_prefix = local.prefix
  environment     = var.environment
  aws_region      = var.aws_region
  # Networking - from common.tfvars and SSM
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  vpc_cidr          = var.vpc_cidr  # Now from common.tfvars
  # Data consolidation configuration
  source_bucket_name       = data.aws_ssm_parameter.readings_bucket_name.value
  consolidated_file_name   = var.consolidated_file_name
  consolidated_path        = var.consolidated_path
  sensor_data_path            = var.sensor_data_path
  # ECS Configuration
  task_cpu            = var.task_cpu
  task_memory         = var.task_memory
  log_retention_days  = var.log_retention_days
  log_group_name      = "${local.prefix}-consolidation-logs"
  # API Gateway configuration
  api_key_name        = "${local.prefix}-api-key"
  usage_plan_name     = "${local.prefix}-usage-plan"
  # Scheduling
  schedule_expression = var.schedule_expression
  # Tags - from common.tfvars
  tags = local.tags
}

#################################################
# RESOURCES
#################################################
# DATA ENGINEERING SERVICE STACK
