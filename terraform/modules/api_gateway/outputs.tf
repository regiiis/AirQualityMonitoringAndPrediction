output "api_gateway_arn" {
  description = "The execution ARN of the API Gateway"
  value       = "${aws_api_gateway_rest_api.air_quality_api.execution_arn}/*"
}

output "api_invoke_url" {
  description = "The invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_api_gateway_rest_api.air_quality_api.id
}

# Add this missing output referenced in dev/outputs.tf
output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}"
}

# Add this missing output referenced in dev/outputs.tf
output "api_key" {
  description = "The API key for device authentication"
  value       = aws_api_gateway_api_key.device_key.value
  sensitive   = true
}
