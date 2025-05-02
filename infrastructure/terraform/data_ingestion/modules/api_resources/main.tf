#################################################
# DATA INGESTION API RESOURCES
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
# DATA INGESTION API PATHS
#################################################
# Creates the /readings resource under the data-ingestion path
resource "aws_api_gateway_resource" "readings" {
  rest_api_id = var.api_id
  parent_id   = var.data_ingestion_resource_id
  path_part   = "readings"
}

# Defines the POST method on the /data-ingestion/readings resource
resource "aws_api_gateway_method" "post_readings" {
  rest_api_id      = var.api_id
  resource_id      = aws_api_gateway_resource.readings.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

#################################################
# LAMBDA INTEGRATION
#################################################
resource "aws_api_gateway_integration" "validator_integration" {
  rest_api_id             = var.api_id
  resource_id             = aws_api_gateway_resource.readings.id
  http_method             = aws_api_gateway_method.post_readings.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.data_validator_lambda_invoke_arn
}

# Create or update deployment to apply changes
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = var.api_id

  triggers = {
    # This will force a new deployment whenever the integration changes
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.readings.id,
      aws_api_gateway_method.post_readings.id,
      aws_api_gateway_integration.validator_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  # Explicit dependency to ensure resources are created before deployment
  depends_on = [
    aws_api_gateway_method.post_readings,
    aws_api_gateway_integration.validator_integration
  ]
}
