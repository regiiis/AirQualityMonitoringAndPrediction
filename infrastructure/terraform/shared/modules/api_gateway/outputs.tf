output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_api_gateway_rest_api.shared_api.id
}

output "api_execution_arn" {
  description = "The execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.shared_api.execution_arn
}

output "api_invoke_url" {
  description = "The invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = aws_api_gateway_stage.api_stage.stage_name
}

output "api_key" {
  description = "The API key for device authentication"
  value       = aws_api_gateway_api_key.device_key.value
  sensitive   = true
}

output "data_ingestion_resource_id" {
  description = "The ID of the data ingestion resource"
  value       = aws_api_gateway_resource.data_ingestion.id
}

output "data_processing_resource_id" {
  description = "The ID of the data processing resource"
  value       = aws_api_gateway_resource.data_processing.id
}

output "visualization_resource_id" {
  description = "The ID of the visualization resource"
  value       = aws_api_gateway_resource.visualization.id
}
