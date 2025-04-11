output "api_gateway_url" {
  description = "The URL of the deployed API Gateway"
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "api_key" {
  description = "The API key for ESP32 device authentication"
  value       = aws_api_gateway_api_key.device_key.value
}

output "api_gateway_arn" {
  description = "The ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.air_quality_api.execution_arn
}
