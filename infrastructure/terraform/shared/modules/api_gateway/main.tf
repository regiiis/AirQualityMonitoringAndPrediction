#################################################
# SHARED API GATEWAY MODULE
#################################################
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#################################################
# API GATEWAY CORE CONFIGURATION
#################################################
resource "aws_api_gateway_rest_api" "shared_api" {
  name = "${var.resource_prefix}-api"
  description = "Shared API Gateway for Air Quality Monitoring System"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    {
      Name = "${var.resource_prefix}-api"
      ResourceType = "SharedInfrastructure"
    },
    var.tags
  )
}

#################################################
# DEPLOYMENT CONFIGURATION
#################################################
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.shared_api.id

  # This will force a new deployment on any change
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.shared_api))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.shared_api.id
  stage_name    = var.stage_name

  xray_tracing_enabled  = true
  cache_cluster_enabled = false

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  tags = merge(
    {
      Name = "${var.environment}-shared-api-stage-${var.stage_name}"
    },
    var.tags
  )
}

#################################################
# MICROSERVICE PATHS
#################################################
# Creates a resource for each major microservice
resource "aws_api_gateway_resource" "data_ingestion" {
  rest_api_id = aws_api_gateway_rest_api.shared_api.id
  parent_id   = aws_api_gateway_rest_api.shared_api.root_resource_id
  path_part   = "data-ingestion"
}

resource "aws_api_gateway_resource" "data_processing" {
  rest_api_id = aws_api_gateway_rest_api.shared_api.id
  parent_id   = aws_api_gateway_rest_api.shared_api.root_resource_id
  path_part   = "data-processing"
}

resource "aws_api_gateway_resource" "visualization" {
  rest_api_id = aws_api_gateway_rest_api.shared_api.id
  parent_id   = aws_api_gateway_rest_api.shared_api.root_resource_id
  path_part   = "visualization"
}

#################################################
# API KEYS AND USAGE PLAN
#################################################
resource "aws_api_gateway_api_key" "device_key" {
  name = "${var.resource_prefix}-device-key"
  tags = merge(
    {
      Name = var.api_key_name
    },
    var.tags
  )
}

resource "aws_api_gateway_usage_plan" "device_plan" {
  name = var.usage_plan_name

  api_stages {
    api_id = aws_api_gateway_rest_api.shared_api.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }

  quota_settings {
    limit  = 50000
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 1
  }

  tags = merge(
    {
      Name = var.usage_plan_name
    },
    var.tags
  )
}

resource "aws_api_gateway_usage_plan_key" "device_plan_key" {
  key_id        = aws_api_gateway_api_key.device_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.device_plan.id
}

# Create a CloudWatch Log Group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = var.log_group_name
  retention_in_days = 365
  tags = merge(
    {
      Name = var.log_group_name
    },
    var.tags
  )
}

#################################################
# SSM PARAMETERS FOR SERVICE INTEGRATION
#################################################
resource "aws_ssm_parameter" "api_id" {
  name  = "/shared/${var.environment}/api-gateway/id"
  type  = "String"
  value = aws_api_gateway_rest_api.shared_api.id
  tags  = var.tags
}

resource "aws_ssm_parameter" "api_execution_arn" {
  name  = "/shared/${var.environment}/api-gateway/execution-arn"
  type  = "String"
  value = aws_api_gateway_rest_api.shared_api.execution_arn
  tags  = var.tags
}

resource "aws_ssm_parameter" "api_stage_name" {
  name  = "/shared/${var.environment}/api-gateway/stage-name"
  type  = "String"
  value = aws_api_gateway_stage.api_stage.stage_name
  tags  = var.tags
}

resource "aws_ssm_parameter" "api_invoke_url" {
  name  = "/shared/${var.environment}/api-gateway/invoke-url"
  type  = "String"
  value = aws_api_gateway_stage.api_stage.invoke_url
  tags  = var.tags
}

resource "aws_ssm_parameter" "data_ingestion_resource_id" {
  name  = "/shared/${var.environment}/api-gateway/data-ingestion-resource-id"
  type  = "String"
  value = aws_api_gateway_resource.data_ingestion.id
  tags  = var.tags
}
