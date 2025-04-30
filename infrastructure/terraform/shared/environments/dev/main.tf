#################################################
# SHARED INFRASTRUCTURE CONFIGURATION
#################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get AWS account ID for globally unique naming
data "aws_caller_identity" "current" {}

locals {
  # Create a globally unique prefix for resources
  prefix = "${var.project_prefix}-${data.aws_caller_identity.current.account_id}-${var.environment}"
  short_prefix = "${var.project_prefix}-${var.environment}"
}

#################################################
# VPC AND NETWORKING
#################################################
module "vpc" {
  source               = "../../modules/vpc"
  environment          = var.environment
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  tags                 = var.tags
}

#################################################
# SHARED STORAGE
#################################################
module "storage" {
  source      = "../../modules/storage"
  bucket_name = "${local.prefix}-sensor-data"
  environment = var.environment
  tags        = var.tags
}

#################################################
# CLOUDFORMATION STACK FOR SHARED INFRASTRUCTURE
#################################################
resource "aws_cloudformation_stack" "shared_infrastructure" {
  name = "${local.short_prefix}-shared-infrastructure"

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
        "Name": "${local.short_prefix}-shared-resources",
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

  depends_on = [
    module.vpc,
    module.storage
  ]
}

# Export outputs for easy access
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "sensor_data_bucket" {
  value = module.storage.bucket_name
}

#################################################
# API GATEWAY
#################################################
module "api_gateway" {
  source         = "../../modules/api_gateway"
  api_name       = "${local.short_prefix}-shared-api"
  api_key_name   = "${local.short_prefix}-device-key"
  usage_plan_name = "${var.environment}-device-usage-plan"
  log_group_name = "/aws/apigateway/${var.environment}-shared-api"
  stage_name     = "v1"
  environment    = var.environment
  tags           = var.tags
}
