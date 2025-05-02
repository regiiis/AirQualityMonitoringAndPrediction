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
    dynamodb_table = "airq-terraform-lock-table"
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
    var.data_ingestion_tags
  )


  lambda_zip_path = "${path.module}/${var.data_ingestion_zip_path}"
}

#################################################
# MODULES
#################################################
# LAMBDA FUNCTIONS
module "lambda" {
  source                       = "./modules/lambda_function"
  resource_prefix              = local.prefix
  data_ingestion_function_name = "${local.prefix}-${var.data_ingestion_function_name}"
  data_ingestion_bucket_name   = data.aws_ssm_parameter.readings_bucket_name.value
  data_ingestion_zip_path      = local.lambda_zip_path
  subnet_ids                   = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  security_group_id            = data.aws_ssm_parameter.lambda_security_group_id.value
  environment                  = var.environment
  api_gateway_execution_arn    = data.aws_ssm_parameter.api_execution_arn.value
  tags                         = local.tags
}

# API RESOURCES
module "api_resources" {
  source                           = "./modules/api_resources"
  resource_prefix                  = local.prefix
  api_id                           = data.aws_ssm_parameter.api_id.value
  data_ingestion_resource_id       = data.aws_ssm_parameter.data_ingestion_resource_id.value
  data_validator_lambda_invoke_arn = module.lambda.data_ingestion_function_invoke_arn
}

#################################################
# RESOURCES
#################################################
# DATA INGESTION SERVICE STACK
resource "aws_cloudformation_stack" "data_ingestion_service" {
  name = "${local.prefix}-data-ingestion-service"

  template_body = <<EOT
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "Data Ingestion Service for Air Quality Monitoring",
  "Parameters": {
    "LambdaFunctionName": {
      "Type": "String",
      "Default": "${module.lambda.data_ingestion_function_name}"
    },
    "SensorDataBucketName": {
      "Type": "AWS::SSM::Parameter::Value<String>",
      "Default": "/shared/${var.environment}/storage/readings-bucket-name"
    },
    "SharedApiId": {
      "Type": "AWS::SSM::Parameter::Value<String>",
      "Default": "/shared/${var.environment}/api-gateway/id"
    }
  },
  "Resources": {
    "DataIngestionMonitoring": {
      "Type": "AWS::CloudWatch::Dashboard",
      "Properties": {
        "DashboardName": "${local.prefix}-data-ingestion-dashboard",
        "DashboardBody": {
          "Fn::Join": ["", [
            "{\"widgets\":[{\"type\":\"metric\",\"x\":0,\"y\":0,\"width\":12,\"height\":6,\"properties\":{\"metrics\":[[\"AWS/Lambda\",\"Invocations\",\"FunctionName\",\"", {"Ref": "LambdaFunctionName"}, "\"]],\"view\":\"timeSeries\",\"region\":\"", {"Ref": "AWS::Region"}, "\",\"title\":\"Lambda Invocations\"}}]}"
          ]]
        }
      }
    },
    "ApiUsageAlarm": {
      "Type": "AWS::CloudWatch::Alarm",
      "Properties": {
        "AlarmName": "${local.prefix}-api-4xx-errors",
        "MetricName": "4XXError",
        "Namespace": "AWS/ApiGateway",
        "Dimensions": [
          {
            "Name": "ApiId",
            "Value": {"Ref": "SharedApiId"}
          },
          {
            "Name": "Stage",
            "Value": "v1"
          }
        ],
        "Statistic": "Sum",
        "Period": 60,
        "EvaluationPeriods": 1,
        "Threshold": 10,
        "ComparisonOperator": "GreaterThanThreshold",
        "AlarmDescription": "Alert when too many 4XX errors occur on the API"
      }
    }
  }
}
EOT

  capabilities = ["CAPABILITY_IAM"]
  depends_on   = [module.lambda, module.api_resources]
}
