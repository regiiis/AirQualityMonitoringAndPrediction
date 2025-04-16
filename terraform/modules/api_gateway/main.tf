#################################################
#
#################################################
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
# API GATEWAY CORE CONFIGURATION
#################################################
# Creates the primary API Gateway REST API resource - this is the container for all API components
resource "aws_api_gateway_rest_api" "air_quality_api" {
  name        = var.api_name
  description = "Air Quality Monitoring API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Add lifecycle policy for zero-downtime deployments
  lifecycle {
    create_before_destroy = true
  }
}

#################################################
# API RESOURCES AND METHODS
#################################################
# Creates the /readings resource path - this is the endpoint ESP32 devices will send data to
resource "aws_api_gateway_resource" "readings" {
  rest_api_id = aws_api_gateway_rest_api.air_quality_api.id
  parent_id   = aws_api_gateway_rest_api.air_quality_api.root_resource_id
  path_part   = "readings"
}

# Defines the POST method on the /readings resource
resource "aws_api_gateway_method" "post_readings" {
  rest_api_id   = aws_api_gateway_rest_api.air_quality_api.id
  resource_id   = aws_api_gateway_resource.readings.id
  http_method   = "POST"
  authorization = "API_KEY"
}

#################################################
# LAMBDA INTEGRATION
#################################################
# Connects the POST /readings endpoint to the data validator Lambda function
resource "aws_api_gateway_integration" "validator_integration" {
  rest_api_id             = aws_api_gateway_rest_api.air_quality_api.id
  resource_id             = aws_api_gateway_resource.readings.id
  http_method             = aws_api_gateway_method.post_readings.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.data_validator_lambda_invoke_arn
}

#################################################
# API DEPLOYMENT CONFIGURATION
#################################################
# Creates a deployment snapshot of the API configuration
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.air_quality_api.id

  # Ensure API is deployed after all resources and methods are created
  depends_on = [
    aws_api_gateway_integration.validator_integration
  ]

  # Lifecycle policy to avoid deployment issues during updates
  lifecycle {
    create_before_destroy = true
  }
}

# Creates a named v1 stage for the API - this forms part of the URL
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id         = aws_api_gateway_deployment.api_deployment.id
  rest_api_id           = aws_api_gateway_rest_api.air_quality_api.id
  stage_name            = "v1" # Creates /v1 prefix in API URL: https://api-id.execute-api.region.amazonaws.com/v1/readings
  xray_tracing_enabled  = true # Enable X-Ray tracing for better observability
  cache_cluster_enabled = true # Enable caching for improved performance

  # Add access logging configuration
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
}

#################################################
# API KEYS AND USAGE PLAN
#################################################
# Creates an API key for ESP32 device authentication
resource "aws_api_gateway_api_key" "device_key" {
  name = "esp32-device-key"
}

# Defines usage limits and throttling settings for the API
resource "aws_api_gateway_usage_plan" "device_plan" {
  name = "esp32-usage-plan"

  # Associates this plan with the v1 stage of our API
  api_stages {
    api_id = aws_api_gateway_rest_api.air_quality_api.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }

  # Monthly quota limits - 50000 requests/month
  # Suitable for air quality monitoring with 10-minute intervals
  quota_settings {
    limit  = 50000
    period = "MONTH"
  }

  # Rate limiting to protect API and backend resources
  throttle_settings {
    burst_limit = 5 # Allow bursts of up to 5 requests
    rate_limit  = 1 # Normal operation: 1 request per second
  }
}

# Links the ESP32 API key to the usage plan
resource "aws_api_gateway_usage_plan_key" "device_plan_key" {
  key_id        = aws_api_gateway_api_key.device_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.device_plan.id
}

# Create a CloudWatch Log Group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = 365 # Adjust retention period as needed
}
