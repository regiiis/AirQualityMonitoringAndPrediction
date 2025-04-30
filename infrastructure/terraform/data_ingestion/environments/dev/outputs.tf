#################################################
# ENVIRONMENT OUTPUTS
#################################################
# This file defines the outputs from the dev environment deployment
# These values will be displayed after terraform apply completes
# and can be used by other systems or for documentation

#################################################
# API GATEWAY OUTPUTS
#################################################
output "api_gateway_url" {
  description = "URL of the deployed API Gateway"
  value       = module.api_gateway.api_gateway_url
  # This URL can be used by ESP32 devices to submit readings
}

output "api_key" {
  description = "API key for ESP32 device authentication"
  value       = module.api_gateway.api_key
  sensitive   = true # Marked as sensitive to prevent showing in logs
}

#################################################
# STORAGE OUTPUTS
#################################################
output "bucket_name" {
  description = "S3 bucket name for air quality readings"
  value       = module.database.bucket_name
  # This bucket stores all air quality data collected by devices
}

output "account_id" {
  description = "The AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
