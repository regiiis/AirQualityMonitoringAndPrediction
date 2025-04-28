#################################################
# TERRAFORM CONFIGURATION
#################################################
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
# API GATEWAY CORE CONFIGURATION
#################################################
# Creates the primary API Gateway REST API resource - this is the container for all API components
resource "aws_api_gateway_rest_api" "air_quality_api" {
  name        = var.api_name                 # Name of the API from variables
  description = "Air Quality Monitoring API" # Human-readable description

  endpoint_configuration {
    types = ["REGIONAL"] # Regional deployment for better latency in the region
  }

  # Add lifecycle policy for zero-downtime deployments
  lifecycle {
    create_before_destroy = true # Creates new API before destroying old one
  }

  tags = {
    Name = "${var.environment}-air-quality-api"
  }
}

#################################################
# API RESOURCES AND METHODS
#################################################
# Creates the /readings resource path - this is the endpoint ESP32 devices will send data to
resource "aws_api_gateway_resource" "readings" {
  rest_api_id = aws_api_gateway_rest_api.air_quality_api.id               # Links to parent API
  parent_id   = aws_api_gateway_rest_api.air_quality_api.root_resource_id # Root level resource
  path_part   = "readings"                                                # Creates /readings endpoint
}

# Defines the POST method on the /readings resource
resource "aws_api_gateway_method" "post_readings" {
  rest_api_id   = aws_api_gateway_rest_api.air_quality_api.id # Links to parent API
  resource_id   = aws_api_gateway_resource.readings.id        # Links to readings resource
  http_method   = "POST"                                      # Only allow POST requests for data submission
  authorization = "API_KEY"                                   # Requires API key for security
}

#################################################
# LAMBDA INTEGRATION
#################################################
# Connects the POST /readings endpoint to the data validator Lambda function
resource "aws_api_gateway_integration" "validator_integration" {
  rest_api_id             = aws_api_gateway_rest_api.air_quality_api.id      # Links to parent API
  resource_id             = aws_api_gateway_resource.readings.id             # Links to readings resource
  http_method             = aws_api_gateway_method.post_readings.http_method # Links to POST method
  integration_http_method = "POST"                                           # Lambda always receives POST
  type                    = "AWS_PROXY"                                      # Use Lambda proxy integration for easier request handling
  uri                     = var.data_validator_lambda_invoke_arn             # Points to Lambda function
}

#################################################
# API DEPLOYMENT CONFIGURATION
#################################################
# Creates a deployment snapshot of the API configuration
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.air_quality_api.id # Links to parent API

  # Ensure API is deployed after all resources and methods are created
  depends_on = [
    aws_api_gateway_integration.validator_integration # Wait for integration to be created
  ]

  # Lifecycle policy to avoid deployment issues during updates
  lifecycle {
    create_before_destroy = true # Creates new deployment before destroying old one
  }
}

# Creates a named v1 stage for the API - this forms part of the URL
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id         = aws_api_gateway_deployment.api_deployment.id # Links to deployment
  rest_api_id           = aws_api_gateway_rest_api.air_quality_api.id  # Links to parent API
  stage_name            = "v1"                                         # Creates /v1 prefix in API URL
  xray_tracing_enabled  = true                                         # Enable X-Ray tracing for better observability
  cache_cluster_enabled = true                                         # Enable caching for improved performance

  # Add access logging configuration
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn # Log destination
    format = jsonencode({                                           # Structured JSON log format for easier analysis
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

  tags = {
    Name = "${var.environment}-api-stage-v1"
  }
}

#################################################
# API KEYS AND USAGE PLAN
#################################################
# Creates an API key for ESP32 device authentication
resource "aws_api_gateway_api_key" "device_key" {
  name = "esp32-device-key" # Name of the API key for devices

  tags = {
    Name = "${var.environment}-esp32-device-key"
  }
}

# Defines usage limits and throttling settings for the API
resource "aws_api_gateway_usage_plan" "device_plan" {
  name = "esp32-usage-plan" # Name of the usage plan

  # Associates this plan with the v1 stage of our API
  api_stages {
    api_id = aws_api_gateway_rest_api.air_quality_api.id # Links to parent API
    stage  = aws_api_gateway_stage.api_stage.stage_name  # Links to v1 stage
  }

  # Monthly quota limits - 50000 requests/month
  # Suitable for air quality monitoring with 10-minute intervals
  quota_settings {
    limit  = 50000   # Monthly request limit
    period = "MONTH" # Quota period
  }

  # Rate limiting to protect API and backend resources
  throttle_settings {
    burst_limit = 5 # Allow bursts of up to 5 requests
    rate_limit  = 1 # Normal operation: 1 request per second
  }

  tags = {
    Name = "${var.environment}-esp32-usage-plan"
  }
}

# Links the ESP32 API key to the usage plan
resource "aws_api_gateway_usage_plan_key" "device_plan_key" {
  key_id        = aws_api_gateway_api_key.device_key.id     # Links to API key
  key_type      = "API_KEY"                                 # Key type
  usage_plan_id = aws_api_gateway_usage_plan.device_plan.id # Links to usage plan
}

# Create a CloudWatch Log Group for API Gateway logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}" # Standard naming for API Gateway logs
  retention_in_days = 365                               # 1-year retention period for compliance

  tags = {
    Name = "${var.environment}-api-gateway-logs"
  }
}
