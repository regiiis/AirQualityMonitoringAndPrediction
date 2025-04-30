# Get shared infrastructure details
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/${var.environment}/vpc/id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/${var.environment}/vpc/private-subnet-ids"
}

data "aws_ssm_parameter" "lambda_security_group_id" {
  name = "/shared/${var.environment}/vpc/lambda-sg-id"
}

# Get shared storage details
data "aws_ssm_parameter" "readings_bucket_name" {
  name = "/shared/${var.environment}/storage/readings-bucket-name"
}

#################################################
# Get shared API Gateway details
#################################################
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
# LAMBDA FUNCTIONS
#################################################
module "lambda" {
  source                       = "../../modules/lambda"
  data_ingestion_function_name = "${local.prefix}-${var.data_ingestion_function_name}"
  data_ingestion_bucket_name   = data.aws_ssm_parameter.readings_bucket_name.value
  data_ingestion_zip_path      = var.data_ingestion_zip_path
  subnet_ids                   = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  security_group_id            = data.aws_ssm_parameter.lambda_security_group_id.value
  environment                  = var.environment
  # Now use the shared API Gateway execution ARN
  api_gateway_execution_arn    = data.aws_ssm_parameter.api_execution_arn.value
  tags                         = var.tags
}

#################################################
# API RESOURCES FOR DATA INGESTION
#################################################
module "api_resources" {
  source                       = "../../modules/api_resources"
  api_id                       = data.aws_ssm_parameter.api_id.value
  data_ingestion_resource_id   = data.aws_ssm_parameter.data_ingestion_resource_id.value
  data_validator_lambda_invoke_arn = module.lambda.data_ingestion_function_invoke_arn
  tags                         = var.tags
}

#################################################
# DATA INGESTION SERVICE STACK
#################################################
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

  depends_on = [
    module.lambda,
    module.api_resources
  ]
}
