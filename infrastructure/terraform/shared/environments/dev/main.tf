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
    bucket         = var.tf_state_bucket
    key            = "${var.environment}/shared/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "airq-terraform-lock"
    encrypt        = true
  }
}

#################################################
# PROVIDER CONFIGURATION
#################################################
provider "aws" {
  region = var.aws_region
}

#################################################
# LOCAL VARIABLES
#################################################
locals {
  # Create a globally unique prefix for resources
  prefix = "${var.project_prefix}-${var.environment}"

  # Merge tags for shared infrastructure
  tags = merge(
    var.common_tags,
    var.environment_tags,
    var.shared_tags
  )
}

#################################################
# MODULES
#################################################
# VPC AND NETWORKING
module "vpc" {
  source               = "../../modules/vpc"
  resource_prefix      = local.prefix
  environment          = var.environment
  availability_zones   = var.availability_zones
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.tags
}

# SHARED STORAGE
module "storage" {
  source          = "../../modules/storage"
  resource_prefix = local.prefix
  bucket_name     = "${local.prefix}-${var.bucket_name}"
  environment     = var.environment
  tags            = local.tags
}

# API GATEWAY
module "api_gateway" {
  source          = "../../modules/api_gateway"
  resource_prefix = local.prefix
  api_name        = "${local.prefix}-${var.api_name}"
  api_key_name    = "${local.prefix}-device-key"
  usage_plan_name = "${var.environment}-device-usage-plan"
  log_group_name  = "/aws/apigateway/${var.environment}-${var.api_name}"
  stage_name      = "v1"
  environment     = var.environment
  tags            = local.tags
}

#################################################
# RESOURCES
#################################################
# CLOUDFORMATION STACK FOR SHARED INFRASTRUCTURE
resource "aws_cloudformation_stack" "shared_infrastructure" {
  name = "${local.prefix}-shared-infrastructure"

  template_body = <<EOT
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "Shared infrastructure for Air Quality Monitoring System",
  "Parameters": {
    "VpcId": {
      "Type": "AWS::SSM::Parameter::Value<String>",
      "Default": "/shared/${var.environment}/vpc/id"
    },
    "SensorDataBucketName": {
      "Type": "AWS::SSM::Parameter::Value<String>",
      "Default": "/shared/${var.environment}/storage/readings-bucket-name"
    }
  },
  "Resources": {
    "SharedResourceGroup": {
      "Type": "AWS::ResourceGroups::Group",
      "Properties": {
        "Name": "${local.prefix}-shared-resources",
        "Description": "Group containing all shared infrastructure resources",
        "ResourceQuery": {
          "Type": "TAG_FILTERS_1_0",
          "Query": {
            "ResourceTypeFilters": ["AWS::AllSupported"],
            "TagFilters": [
              {
                "Key": "Environment",
                "Values": ["${var.environment}"]
              },
              {
                "Key": "Project",
                "Values": ["${var.project_prefix}"]
              },
              {
                "Key": "ResourceType",
                "Values": ["SharedInfrastructure"]
              }
            ]
          }
        }
      }
    }
  },
  "Outputs": {
    "VpcId": {
      "Description": "VPC ID for shared infrastructure",
      "Value": {"Ref": "VpcId"}
    },
    "SensorDataBucket": {
      "Description": "Bucket name for sensor data",
      "Value": {"Ref": "SensorDataBucketName"}
    }
  }
}
EOT

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
  depends_on   = [module.vpc, module.storage]
}
